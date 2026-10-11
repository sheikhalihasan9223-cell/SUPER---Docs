import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ali_docs/store.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test(
    'Android uses host address and migrates old loopback preferences',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(await SharedPreferences.getInstance());
      expect(store.endpoint, 'http://10.0.2.2:8000');
      await store.settings(endpoint: 'http://127.0.0.1:8000');
      expect(store.endpoint, 'http://10.0.2.2:8000');
      await store.settings(endpoint: 'https://processor.example');
      expect(store.endpoint, 'https://processor.example');
    },
  );
  test('Desktop retains local processor address', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    expect(store.endpoint, 'http://127.0.0.1:8000');
  });
}
