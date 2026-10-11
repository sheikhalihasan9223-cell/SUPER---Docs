import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ali_docs/models.dart';
import 'package:ali_docs/store.dart';
import 'package:ali_docs/workflow.dart';

void main() {
  testWidgets(
    'Completion summary and More save action work on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(await SharedPreferences.getInstance());
      final file = DocFile(
        id: 'result',
        name: 'Converted presentation.pptx',
        bytes: Uint8List.fromList([1, 2, 3]),
        created: DateTime.now(),
        tool: 'PDF to PowerPoint',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ResultScreen(file: file, store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Conversion Completed!'), findsOneWidget);
      expect(find.text(file.name), findsOneWidget);
      await tester.ensureVisible(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save in My files'));
      await tester.pumpAndSettle();
      expect(store.files.single.id, file.id);
      expect(tester.takeException(), isNull);
    },
  );
}
