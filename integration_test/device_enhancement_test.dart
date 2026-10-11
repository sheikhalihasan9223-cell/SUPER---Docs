import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;
import 'package:ali_docs/on_device_enhancement.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Bundled ESRGAN produces offline 2x output on Android', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Offline AI test'))),
    );
    final photo = img.Image(width: 24, height: 24);
    for (var y = 0; y < 24; y++) {
      for (var x = 0; x < 24; x++) {
        photo.setPixelRgb(x, y, x * 10, y * 10, (x + y) * 5);
      }
    }
    double progress = 0;
    final watch = Stopwatch()..start();
    final bytes = await DeviceEnhancementTask().run(
      Uint8List.fromList(img.encodePng(photo)),
      2,
      onProgress: (value) => progress = value,
    );
    final output = img.decodeImage(bytes)!;
    expect(output.width, 48);
    expect(output.height, 48);
    expect(progress, 1);
    expect(output.getPixel(40, 40).r, greaterThan(output.getPixel(4, 4).r));
    debugPrint(
      'Offline ESRGAN inference completed in ${watch.elapsedMilliseconds}ms; ${bytes.length} output bytes',
    );
  });
  testWidgets('Cancel stops tiled AI and frees the worker', (tester) async {
    final photo = img.Image(width: 84, height: 84);
    final task = DeviceEnhancementTask();
    final run = task.run(
      Uint8List.fromList(img.encodePng(photo)),
      2,
      onProgress: (value) {
        if (value < 1) task.cancel();
      },
    );
    await expectLater(run, throwsA(isA<StateError>()));
  });
}
