import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ali_docs/cloud_backend.dart';
import 'package:ali_docs/profile_model.dart';
import 'package:ali_docs/profile_page.dart';
import 'package:ali_docs/store.dart';

class FakeAccount extends ChangeNotifier implements ProfileAccount {
  @override
  AccountProfile? profile = const AccountProfile(
    id: 'user',
    name: 'Ali Hasan',
    email: 'ali@example.com',
  );
  @override
  String? authError;
  @override
  Future<void> updateName(String name) async {
    profile = AccountProfile(
      id: profile!.id,
      name: name,
      email: profile!.email,
    );
    notifyListeners();
  }

  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {
    profile = null;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Signed-in profile displays Google identity and saves an edited name',
    (tester) async {
      final account = FakeAccount();
      final store = AppStore(await SharedPreferences.getInstance())
        ..accountId = 'user';
      await tester.pumpWidget(
        MaterialApp(
          home: ProfilePage(store: store, account: account),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ali Hasan'), findsOneWidget);
      expect(find.text('ali@example.com'), findsOneWidget);
      expect(find.text('Google account'), findsOneWidget);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Ali');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(account.profile!.name, 'Ali');
      await tester.drag(find.byType(ListView), const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(find.text('Profile updated.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Profile sign-out returns to guest view and hides identity', (
    tester,
  ) async {
    final account = FakeAccount();
    final store = AppStore(await SharedPreferences.getInstance())
      ..accountId = 'user';
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(store: store, account: account),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(account.profile, isNull);
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('ali@example.com'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test(
    'OAuth callback errors are surfaced instead of silently leaving guest mode',
    () async {
      final client = SupabaseClient('https://project.test', 'public-key');
      final events = StreamController<AuthState>();
      final backend = SupabaseBackend(
        client,
        url: 'https://project.test',
        publicKey: 'public-key',
        authEvents: events.stream,
      );
      events.addError(
        const AuthException('Unable to exchange external code%3A+private-code'),
        StackTrace.current,
      );
      await Future<void>.delayed(Duration.zero);
      expect(backend.authError, contains('Google login configuration'));
      expect(backend.authError, isNot(contains('private-code')));
      expect(backend.profile, isNull);
      backend.dispose();
      await client.dispose();
      await events.close();
    },
  );
}
