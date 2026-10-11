import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ali_docs/main.dart';
import 'package:ali_docs/store.dart';
import 'package:ali_docs/profile_page.dart';

void main() {
  testWidgets('Profile dark mode applies immediately and persists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(prefs);
    await tester.pumpWidget(AliDocsApp(store: store));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Settings'), findsNothing);
    await tester.tap(find.byTooltip('Profile'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    for (final dark in [true, false, true]) {
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(store.dark, dark);
      expect(prefs.getBool('dark'), dark);
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(Switch))).brightness,
        dark ? Brightness.dark : Brightness.light,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Profile'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Mobile navigation, search and enabled OCR workflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(AliDocsApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('All-in-one\nPDF Workspace'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'OCR');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('OCR PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OCR PDF'));
    await tester.pumpAndSettle();
    expect(find.text('OCR language'), findsOneWidget);
    expect(find.text('Ask Gemini'), findsNothing);
    expect(find.text('Use Gemini AI'), findsNothing);
    expect(find.text('Select files'), findsOneWidget);
    expect(find.text('Part of the next chapter.'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Image tools').last);
    await tester.pumpAndSettle();
    expect(find.text('Compress Image'), findsOneWidget);
    await tester.tap(find.text('My files').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('A fresh start for your documents.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Home hero swipes to enhancement and opens the photo tool', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(AliDocsApp(store: store));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('home-hero-pages')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Enhance a photo'), findsOneWidget);
    await tester.tap(find.text('Enhance a photo'));
    await tester.pumpAndSettle();
    expect(find.text('Enhance Photo'), findsWidgets);
    expect(find.text('Use Upscayl AI'), findsNothing);
    expect(find.text('Use Gemini AI'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Processed on your device. No upload needed.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Desktop and narrow mobile layouts do not overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    for (final size in [
      Size.zero,
      const Size(1440, 900),
      const Size(360, 800),
      const Size(320, 700),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(AliDocsApp(store: store));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
