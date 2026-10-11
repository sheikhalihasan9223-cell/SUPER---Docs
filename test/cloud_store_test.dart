import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ali_docs/cloud_backend.dart';
import 'package:ali_docs/store.dart';
import 'package:ali_docs/models.dart';
import 'package:ali_docs/account_panel.dart';

class FakeCloud implements CloudDocuments {
  @override
  String? userId;
  bool offline = false;
  Completer<void>? gate;
  final Map<String, Map<String, DocFile>> accounts = {};
  @override
  Future<List<DocFile>> list(
    String owner, {
    Map<String, DocFile> cached = const {},
  }) async {
    if (offline) throw StateError('offline');
    return accounts[owner]?.values.toList() ?? [];
  }

  @override
  Future<void> save(String owner, DocFile file) async {
    if (offline) throw StateError('offline');
    await gate?.future;
    (accounts[owner] ??= {})[file.id] = file;
  }

  @override
  Future<void> remove(String owner, String id) async {
    if (offline) throw StateError('offline');
    accounts[owner]?.remove(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  DocFile fixture(String id) => DocFile(
    id: id,
    name: '$id.txt',
    bytes: Uint8List.fromList([1, 2, 3]),
    created: DateTime(2026),
    tool: 'Test',
  );
  Future<void> idle(AppStore store) async {
    for (var i = 0; i < 100 && store.syncing; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('Guest documents stay separate from both Google accounts', () async {
    final cloud = FakeCloud();
    final store = AppStore(await SharedPreferences.getInstance(), cloud: cloud);
    await store.save(fixture('guest'));
    cloud.userId = 'alice';
    await store.switchAccount();
    await idle(store);
    expect(store.files, isEmpty);
    await store.save(fixture('alice-file'));
    await idle(store);
    expect(cloud.accounts['alice']!.keys, ['alice-file']);
    cloud.userId = 'bob';
    await store.switchAccount();
    await idle(store);
    expect(store.files, isEmpty);
    await store.save(fixture('bob-file'));
    await idle(store);
    cloud.userId = 'alice';
    await store.switchAccount();
    await idle(store);
    expect(store.files.single.id, 'alice-file');
    cloud.userId = null;
    await store.switchAccount();
    expect(store.files.single.id, 'guest');
  });
  test(
    'Offline result remains local and retries upload and deletion',
    () async {
      final cloud = FakeCloud()
        ..userId = 'alice'
        ..offline = true;
      final store = AppStore(
        await SharedPreferences.getInstance(),
        cloud: cloud,
      );
      await store.switchAccount();
      await idle(store);
      await store.save(fixture('result'));
      await idle(store);
      expect(store.files.single.id, 'result');
      expect(store.syncError, isNotNull);
      cloud.offline = false;
      await store.sync();
      expect(cloud.accounts['alice']!['result'], isNotNull);
      cloud.offline = true;
      await store.remove(store.files.single);
      await idle(store);
      expect(store.files, isEmpty);
      cloud.offline = false;
      await store.sync();
      expect(cloud.accounts['alice'], isEmpty);
      expect(store.files, isEmpty);
    },
  );
  test(
    'In-flight upload cannot put prior account files into the next account',
    () async {
      final cloud = FakeCloud()..userId = 'alice';
      final store = AppStore(
        await SharedPreferences.getInstance(),
        cloud: cloud,
      );
      await store.switchAccount();
      await idle(store);
      cloud.gate = Completer<void>();
      await store.save(fixture('private'));
      cloud.userId = 'bob';
      await store.switchAccount();
      cloud.gate!.complete();
      await idle(store);
      expect(store.files, isEmpty);
      expect(cloud.accounts['bob'], isNull);
      expect(cloud.accounts['alice']!['private'], isNotNull);
    },
  );
  testWidgets(
    'Guest sees Google sign-in and missing configuration is reported',
    (tester) async {
      final store = AppStore(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AccountPanel(store: store)),
        ),
      );
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(
        find.text('Google sign-in is not available in this build yet.'),
        findsOneWidget,
      );
      expect(store.accountId, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Pending uploads survive restart and remote deletion removes cached entry',
    () async {
      final cloud = FakeCloud()
        ..userId = 'alice'
        ..offline = true;
      final prefs = await SharedPreferences.getInstance();
      final first = AppStore(prefs, cloud: cloud);
      await first.switchAccount();
      await idle(first);
      await first.save(fixture('offline'));
      await idle(first);
      final restarted = AppStore(prefs, cloud: cloud);
      await restarted.switchAccount();
      await idle(restarted);
      expect(restarted.files.single.id, 'offline');
      cloud.offline = false;
      await restarted.sync();
      expect(cloud.accounts['alice']!['offline'], isNotNull);
      cloud.accounts['alice']!.clear();
      await restarted.sync();
      expect(restarted.files, isEmpty);
    },
  );
}
