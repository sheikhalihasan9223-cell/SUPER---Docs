import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'models.dart';

class ProcessingResult {
  final Uint8List bytes;
  final String name;
  const ProcessingResult(this.bytes, this.name);
}

Future<ProcessingResult> processLocal(
  DocTool tool,
  List<DocFile> files,
  Map<String, dynamic> options,
) => compute(localWorker, {
  'id': tool.id,
  'files': files.map((f) => {'name': f.name, 'bytes': f.bytes}).toList(),
  'options': options,
});
Future<ProcessingResult> localWorker(Map<String, dynamic> input) async {
  final id = input['id'] as String;
  final files = input['files'] as List;
  final o = input['options'] as Map;
  if (id == 'image_pdf' || id == 'create' || id == 'scan') {
    final doc = pw.Document();
    final format = o['pageSize'] == 'Letter'
        ? PdfPageFormat.letter
        : PdfPageFormat.a4;
    if (id == 'create') {
      final text = (o['text'] as String? ?? '').trim();
      if (text.isEmpty) {
        throw const FormatException('Enter some text first.');
      }
      doc.addPage(
        pw.MultiPage(
          pageFormat: format,
          build: (_) => text
              .split('\n')
              .map(
                (line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(line, style: const pw.TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
        ),
      );
    } else {
      for (final file in files) {
        final image = decodeDocumentImage(file['bytes']);
        if (image == null) {
          throw FormatException(
            'Cannot decode ${file['name']}. Use JPG, PNG, GIF, BMP, or TIFF.',
          );
        }
        final clean = img.encodeJpg(img.bakeOrientation(image), quality: 92);
        doc.addPage(
          pw.Page(
            pageFormat: format,
            margin: const pw.EdgeInsets.all(20),
            build: (_) => pw.Center(
              child: pw.Image(pw.MemoryImage(clean), fit: pw.BoxFit.contain),
            ),
          ),
        );
      }
    }
    return ProcessingResult(
      await doc.save(),
      id == 'scan' ? 'scan.pdf' : 'document.pdf',
    );
  }
  final archive = Archive();
  Uint8List? single;
  String singleName = '';
  for (var i = 0; i < files.length; i++) {
    final file = files[i];
    var image = decodeDocumentImage(file['bytes']);
    if (image == null) {
      throw FormatException(
        'Cannot decode ${file['name']}. HEIC and WebP encoding are not supported.',
      );
    }
    image = img.bakeOrientation(image);
    if (id == 'image_enhance') {
      image = img.adjustColor(
        image,
        contrast: 1.12,
        brightness: 1.03,
        saturation: 1.08,
      );
    }
    if (id == 'image_resize') {
      final width = int.tryParse('${o['width']}') ?? 0;
      if (width < 1 || width > 10000) {
        throw const FormatException(
          'Width must be between 1 and 10,000 pixels.',
        );
      }
      image = img.copyResize(image, width: width);
    }
    if (o['stripMetadata'] != false) {
      final clean = img.Image(
        width: image.width,
        height: image.height,
        numChannels: image.numChannels,
      );
      img.compositeImage(clean, image);
      image = clean;
    }
    final format = id == 'image_enhance'
        ? 'PNG'
        : id == 'image_convert'
        ? o['format'] ?? 'PNG'
        : 'JPG';
    if (format == 'JPG') {
      final background = img.Image(width: image.width, height: image.height);
      img.fill(background, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(background, image);
      image = background;
    }
    final quality = (o['quality'] as num? ?? 80).round();
    final bytes = switch (format) {
      'PNG' => img.encodePng(image),
      'BMP' => img.encodeBmp(image),
      'GIF' => img.encodeGif(image),
      'TIFF' => img.encodeTiff(image),
      _ => img.encodeJpg(image, quality: quality),
    };
    final base = (file['name'] as String).replaceFirst(RegExp(r'\.[^.]+$'), '');
    final name = '${i + 1}-${base}_output.${format.toString().toLowerCase()}';
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
    single = Uint8List.fromList(bytes);
    singleName = name;
  }
  if (single == null) {
    throw const FormatException('Select at least one file.');
  }
  return files.length == 1
      ? ProcessingResult(single, singleName)
      : ProcessingResult(
          Uint8List.fromList(ZipEncoder().encode(archive)),
          'images.zip',
        );
}

Future<ProcessingResult> processRemote(
  http.Client client,
  String endpoint,
  DocTool tool,
  List<DocFile> files,
  Map<String, dynamic> options, {
  Map<String, String> headers = const {},
}) async {
  final uri = Uri.parse(
    '${endpoint.replaceFirst(RegExp(r'/+$'), '')}/process/${tool.id}',
  );
  if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
    throw const FormatException(
      'Set a valid processing service URL in Settings.',
    );
  }
  final request = http.MultipartRequest('POST', uri);
  request.headers.addAll(headers);
  request.fields['options'] = jsonEncode(options);
  for (final f in files) {
    request.files.add(
      http.MultipartFile.fromBytes('files', f.bytes, filename: f.name),
    );
  }
  final duration = Duration(
    seconds: ['ocr', 'pdf_word', 'pdf_excel', 'pdf_ppt'].contains(tool.id)
        ? 600
        : 120,
  );
  final response = await (() async => http.Response.fromStream(
    await client.send(request),
  ))().timeout(duration);
  if (response.statusCode != 200) {
    String message = 'Processing failed (${response.statusCode}).';
    try {
      message = jsonDecode(response.body)['detail'].toString();
    } catch (_) {}
    throw StateError(message);
  }
  return ProcessingResult(
    response.bodyBytes,
    response.headers['x-output-name'] ?? 'result.pdf',
  );
}

img.Image? decodeDocumentImage(Uint8List bytes) {
  try {
    return img.decodeImage(bytes);
  } catch (_) {
    throw const FormatException(
      'This image is damaged or unsupported. Try JPG or PNG.',
    );
  }
}
