import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ali_docs/store.dart';
import 'package:ali_docs/models.dart';
import 'package:ali_docs/workflow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('super-docs-store-test');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => directory.path,
        );
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  DocFile fixture(String id, int size) => DocFile(
    id: id,
    name: '$id.txt',
    bytes: Uint8List(size),
    created: DateTime(2026),
    tool: 'Test',
  );

  test('Large files survive restart without evicting earlier files', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(prefs);
    await store.initialize();
    await Future.wait([
      store.save(fixture('one', 9 * 1024 * 1024)),
      store.save(fixture('two', 9 * 1024 * 1024)),
    ]);
    final catalog = jsonDecode(prefs.getString('files')!) as List;
    expect(catalog.every((e) => !e.containsKey('bytes')), isTrue);
    final restarted = AppStore(prefs);
    await restarted.initialize();
    expect(restarted.files.map((e) => e.id), ['two', 'one']);
    expect(restarted.files.map((e) => e.bytes.length), [
      9 * 1024 * 1024,
      9 * 1024 * 1024,
    ]);
    await restarted.remove(restarted.files.first);
    final afterDelete = AppStore(prefs);
    await afterDelete.initialize();
    expect(afterDelete.files.single.id, 'one');
  });

  test(
    'Legacy history migrates to disk and preserves names and favorites',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'files',
        jsonEncode([
          {
            'id': 'old',
            'name': 'old.pdf',
            'bytes': base64Encode([1, 2, 3]),
            'created': DateTime(2026).toIso8601String(),
            'tool': 'Scanner',
            'favorite': true,
          },
        ]),
      );
      final store = AppStore(prefs);
      await store.initialize();
      expect(store.files.single.bytes, [1, 2, 3]);
      expect(store.files.single.favorite, isTrue);
      store.files.single.name = 'renamed.pdf';
      await store.persist();
      final restarted = AppStore(prefs);
      await restarted.initialize();
      expect(restarted.files.single.name, 'renamed.pdf');
      expect(restarted.files.single.bytes, [1, 2, 3]);
    },
  );

  testWidgets('Completion saves automatically and reopening keeps one entry', (
    tester,
  ) async {
    final store = AppStore(await SharedPreferences.getInstance());
    final file = fixture('result', 3);
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(file: file, store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.files.single.id, 'result');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(file: file, store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.files.length, 1);
    expect(tester.takeException(), isNull);
  });
}
