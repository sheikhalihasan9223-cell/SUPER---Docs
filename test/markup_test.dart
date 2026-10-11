import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:ali_docs/document_markup.dart';
import 'package:ali_docs/models.dart';

class PreviewPlatform extends PrintingPlatform {
  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  ) async* {
    if ((pages?.first ?? 0) > 1) {
      throw StateError('Page missing');
    }
    yield PreviewRaster();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PreviewRaster extends PdfRaster {
  PreviewRaster()
    : super(80, 120, Uint8List.fromList(List.filled(80 * 120 * 4, 255)));
  @override
  Future<Uint8List> toPng() async {
    final image = img.Image(width: 80, height: 120);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    return Uint8List.fromList(img.encodePng(image));
  }
}

void main() {
  test('All catalog tools are enabled with matching input types', () {
    expect(tools.every((t) => t.available), isTrue);
    expect(tools.firstWhere((t) => t.id == 'word_pdf').inputExtensions, [
      'doc',
      'docx',
    ]);
    expect(tools.firstWhere((t) => t.id == 'ppt_pdf').inputExtensions, [
      'ppt',
      'pptx',
    ]);
    expect(tools.firstWhere((t) => t.id == 'excel_pdf').inputExtensions, [
      'xls',
      'xlsx',
    ]);
  });
  for (final signing in [false, true]) {
    testWidgets(
      signing
          ? 'Typed signature placement and undo'
          : 'Annotation placement, undo and redo',
      (tester) async {
        final previous = PrintingPlatform.instance;
        PrintingPlatform.instance = PreviewPlatform();
        addTearDown(() => PrintingPlatform.instance = previous);
        List<Map<String, dynamic>> operations = [];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DocumentMarkup(
                  bytes: Uint8List(1),
                  signing: signing,
                  onChanged: (v) => operations = v,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, signing ? 'Your name' : 'Text to add'),
          signing ? 'Ali Hasan' : 'Added note',
        );
        final preview = find.byType(Image).first;
        await tester.ensureVisible(preview);
        await tester.pumpAndSettle();
        await tester.tap(preview);
        await tester.pumpAndSettle();
        expect(operations.length, 1);
        expect(operations.single['kind'], signing ? 'signature_text' : 'text');
        expect(operations.single['page'], 1);
        expect(operations.single['x'], closeTo(.5, .01));
        expect(operations.single['text'], signing ? 'Ali Hasan' : 'Added note');
        await tester.ensureVisible(find.text('Undo'));
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(operations, isEmpty);
        await tester.tap(find.text('Redo'));
        await tester.pumpAndSettle();
        expect(operations.length, 1);
        await tester.ensureVisible(preview);
        await tester.pumpAndSettle();
        final previousX = operations.single['x'] as num;
        await tester.timedDrag(
          find.byKey(const ValueKey('mark-0')),
          const Offset(-50, 0),
          const Duration(milliseconds: 300),
        );
        await tester.pumpAndSettle();
        expect(operations.length, 1);
        expect(operations.single['x'], lessThan(previousX));
        final previousWidth = operations.single['width'] as num;
        await tester.timedDrag(
          find.byKey(const ValueKey('resize-0')),
          const Offset(60, 0),
          const Duration(milliseconds: 300),
        );
        await tester.pumpAndSettle();
        expect(operations.single['width'], greaterThan(previousWidth));
        await tester.tap(find.byTooltip('Delete item'));
        await tester.pumpAndSettle();
        expect(operations, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
