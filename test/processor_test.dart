import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:archive/archive.dart';
import 'package:ali_docs/processor.dart';
import 'package:ali_docs/scanner.dart';

void main() {
  final source = img.Image(width: 80, height: 120);
  img.fill(source, color: img.ColorRgb8(180, 80, 50));
  final bytes = Uint8List.fromList(img.encodePng(source));
  Map<String, dynamic> request(String id, {List? files, Map? options}) => {
    'id': id,
    'files':
        files ??
        [
          {'name': 'photo.png', 'bytes': bytes},
        ],
    'options': options ?? {},
  };
  test(
    'Automatic enhancement preserves image size and transparent pixels',
    () async {
      final image = img.Image(width: 30, height: 40, numChannels: 4);
      img.fill(image, color: img.ColorRgba8(120, 100, 80, 128));
      final result = await localWorker(
        request(
          'image_enhance',
          files: [
            {
              'name': 'photo.png',
              'bytes': Uint8List.fromList(img.encodePng(image)),
            },
          ],
        ),
      );
      final output = img.decodePng(result.bytes)!;
      expect(output.width, 30);
      expect(output.height, 40);
      expect(output.getPixel(15, 20).a, 128);
      expect(output.getPixel(15, 20).r, isNot(120));
      expect(result.name, endsWith('.png'));
    },
  );
  test('Transparent JPG pixels flatten to white', () async {
    final transparent = img.Image(width: 20, height: 20, numChannels: 4);
    final input = Uint8List.fromList(img.encodePng(transparent));
    final result = await localWorker(
      request(
        'image_jpg',
        files: [
          {'name': 'alpha.png', 'bytes': input},
        ],
      ),
    );
    final pixel = img.decodeJpg(result.bytes)!.getPixel(10, 10);
    expect(pixel.r, greaterThan(245));
    expect(pixel.g, greaterThan(245));
    expect(pixel.b, greaterThan(245));
  });
  test('Invalid width text fails instead of silently resizing', () async {
    await expectLater(
      localWorker(request('image_resize', options: {'width': 'abc'})),
      throwsFormatException,
    );
  });
  test('Resize preserves aspect ratio and produces real JPEG bytes', () async {
    final result = await localWorker(
      request('image_resize', options: {'width': '40'}),
    );
    final decoded = img.decodeJpg(result.bytes)!;
    expect(decoded.width, 40);
    expect(decoded.height, 60);
  });
  test('Batch conversion produces independent PNG entries', () async {
    final result = await localWorker(
      request(
        'image_convert',
        files: [
          {'name': 'a.png', 'bytes': bytes},
          {'name': 'b.png', 'bytes': bytes},
        ],
        options: {'format': 'PNG'},
      ),
    );
    final zip = ZipDecoder().decodeBytes(result.bytes);
    expect(zip.files.length, 2);
    expect(img.decodePng(zip.files[0].content)?.width, 80);
  });
  test('Image PDF and text PDF are actual documents', () async {
    final result = await localWorker(request('image_pdf'));
    expect(String.fromCharCodes(result.bytes.take(5)), '%PDF-');
    final note = await localWorker(
      request('create', options: {'text': 'Hello world'}),
    );
    expect(String.fromCharCodes(note.bytes.take(5)), '%PDF-');
  });
  test('Invalid images and dimensions fail clearly', () async {
    await expectLater(
      localWorker(request('image_resize', options: {'width': '0'})),
      throwsFormatException,
    );
    await expectLater(
      localWorker(
        request(
          'image_jpg',
          files: [
            {'name': 'bad.png', 'bytes': Uint8List(3)},
          ],
        ),
      ),
      throwsFormatException,
    );
  });
  test('Scanner rectifies a selected region and applies grayscale', () {
    final result = rectifyScan({
      'bytes': bytes,
      'filter': 'Grayscale',
      'points': [
        [0.1, 0.1],
        [0.9, 0.1],
        [0.9, 0.9],
        [0.1, 0.9],
      ],
    });
    final image = img.decodeJpg(result)!;
    expect(image.width, lessThan(80));
    final pixel = image.getPixel(20, 20);
    expect((pixel.r - pixel.g).abs(), lessThan(3));
  });
  test('Scanner rejects crossed corners', () {
    expect(
      () => rectifyScan({
        'bytes': bytes,
        'filter': 'Original',
        'points': [
          [0.1, 0.1],
          [0.9, 0.9],
          [0.9, 0.1],
          [0.1, 0.9],
        ],
      }),
      throwsFormatException,
    );
  });
}
