import 'package:shared_preferences/shared_preferences.dart';
import 'package:ali_docs/store.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ali_docs/scanner.dart';

void main() {
  Uint8List fixture() {
    final image = img.Image(width: 200, height: 300);
    img.fill(image, color: img.ColorRgb8(25, 25, 25));
    img.fillRect(
      image,
      x1: 20,
      y1: 30,
      x2: 180,
      y2: 270,
      color: img.ColorRgb8(245, 245, 245),
    );
    return Uint8List.fromList(img.encodePng(image));
  }

  test(
    'Automatic crop estimates the paper boundary and rotation preserves pixels',
    () {
      final corners = detectScanCorners(fixture());
      expect(corners[0][0], closeTo(.1, .025));
      expect(corners[0][1], closeTo(.1, .025));
      expect(corners[2][0], closeTo(.9, .025));
      expect(corners[2][1], closeTo(.9, .025));
      final rotated = rotateScan(fixture());
      expect(rotated['ratio'], closeTo(1.5, .001));
      final image = img.decodeImage(rotated['bytes']);
      expect(image!.width, 300);
      expect(image.height, 200);
    },
  );
  testWidgets('Dark crop screen exposes reference actions and movable edges', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: ScanEditor(bytes: fixture())));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.text('Crop'), findsOneWidget);
    expect(find.text('Rotate'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('No Crop'), findsOneWidget);
    expect(find.text('Auto Crop'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Document corner 1, drag to adjust'),
      findsOneWidget,
    );
    await tester.tap(find.text('No Crop'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Filter taps update preview and Original restores color', (
    tester,
  ) async {
    final image = img.Image(width: 60, height: 80);
    img.fill(image, color: img.ColorRgb8(200, 70, 35));
    await tester.pumpWidget(
      MaterialApp(
        home: ScanEditor(bytes: Uint8List.fromList(img.encodePng(image))),
      ),
    );
    Future<void> finishRender() async {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
    }

    await finishRender();
    img.Pixel previewPixel() {
      final widget = tester.widget<Image>(
        find.byKey(const ValueKey('scan-filter-preview')),
      );
      final image = img.decodeImage((widget.image as MemoryImage).bytes)!;
      return image.getPixel(image.width ~/ 2, image.height ~/ 2);
    }

    expect(previewPixel().r - previewPixel().g, greaterThan(50));
    await tester.ensureVisible(find.text('Grayscale'));
    await tester.tap(find.text('Grayscale'));
    await finishRender();
    expect((previewPixel().r - previewPixel().g).abs(), lessThan(3));
    await tester.ensureVisible(find.text('Original'));
    await tester.tap(find.text('Original'));
    await finishRender();
    expect(previewPixel().r - previewPixel().g, greaterThan(50));
    await tester.ensureVisible(find.text('Grayscale'));
    await tester.tap(find.text('Grayscale'));
    await tester.ensureVisible(find.text('Original'));
    await tester.tap(find.text('Original'));
    await finishRender();
    expect(previewPixel().r - previewPixel().g, greaterThan(50));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Scan completion offers PDF save, share and continue actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScanSuccessPage(
          image: fixture(),
          pdf: Uint8List.fromList([1, 2, 3]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Scan completed!'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Continue scanning'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Confirming a scan builds a real PDF and continue returns the page',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(await SharedPreferences.getInstance());
      Uint8List? kept;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  kept = await Navigator.push<Uint8List>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ScanEditor(bytes: fixture(), store: store),
                    ),
                  );
                },
                child: const Text('Start scan'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start scan'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      for (
        var attempt = 0;
        attempt < 30 && find.byType(ScanSuccessPage).evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      final success = tester.widget<ScanSuccessPage>(
        find.byType(ScanSuccessPage),
      );
      expect(String.fromCharCodes(success.pdf.take(4)), '%PDF');
      expect(store.files.single.bytes, success.pdf);
      expect(store.files.single.extension, 'pdf');
      expect(success.saved, isTrue);
      expect(img.decodeImage(success.image), isNotNull);
      await tester.drag(find.byType(ListView), const Offset(0, -450));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue scanning'));
      await tester.pumpAndSettle();
      expect(kept, isNotNull);
      expect(img.decodeImage(kept!), isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
