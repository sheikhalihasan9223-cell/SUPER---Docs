import 'dart:async';
import 'package:ali_docs/main.dart';
import 'package:ali_docs/startup_page.dart';
import 'package:ali_docs/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Full logo remains visible until the workspace is ready', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final ready = Completer<AppStore>();
    await tester.pumpWidget(StartupApp(load: () => ready.future));
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/branding/super_docs_logo.png',
    );
    expect(find.byType(AliDocsApp), findsNothing);
    ready.complete(AppStore(await SharedPreferences.getInstance()));
    await tester.pumpAndSettle();
    expect(find.byType(AliDocsApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
