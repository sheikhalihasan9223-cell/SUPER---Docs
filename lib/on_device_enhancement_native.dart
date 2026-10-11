import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

final supportsDeviceAi = Platform.isAndroid || Platform.isIOS;

class DeviceEnhancementTask {
  Isolate? _worker;
  SendPort? _control;
  Completer<Uint8List>? _result;
  bool _canceled = false;
  Future<Uint8List> run(
    Uint8List bytes,
    int scale, {
    void Function(double)? onProgress,
  }) async {
    if (!supportsDeviceAi) {
      throw UnsupportedError('On-device AI requires Android or iOS.');
    }
    if (scale != 2 && scale != 4) throw ArgumentError('Choose 2x or 4x.');
    if (_result != null) throw StateError('Enhancement is already running.');
    _result = Completer<Uint8List>();
    _result!.future.ignore();
    final messages = ReceivePort();
    final errors = ReceivePort();
    final exits = ReceivePort();
    final subscription = messages.listen((dynamic event) {
      if (event is SendPort) {
        _control = event;
        if (_canceled) _control!.send(true);
      } else if (event is double) {
        onProgress?.call(event);
      } else if (event is TransferableTypedData && !_result!.isCompleted) {
        _result!.complete(event.materialize().asUint8List());
      } else if (event is String && !_result!.isCompleted) {
        _result!.completeError(StateError(event));
      }
    });
    final errorSubscription = errors.listen((dynamic _) {
      if (!_result!.isCompleted) {
        _result!.completeError(
          StateError('AI enhancement failed. Try basic enhancement.'),
        );
      }
    });
    final exitSubscription = exits.listen((dynamic _) {
      // Result/error messages can arrive immediately after the exit signal.
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        if (!_result!.isCompleted) {
          _result!.completeError(
            StateError(
              'AI enhancement stopped. Try again or use basic enhancement.',
            ),
          );
        }
      });
    });
    try {
      final model = await rootBundle.load('assets/models/esrgan.tflite');
      if (_canceled) throw StateError('Task canceled.');
      _worker = await Isolate.spawn(
        _enhance,
        {
          'reply': messages.sendPort,
          'image': TransferableTypedData.fromList([bytes]),
          'model': TransferableTypedData.fromList([
            model.buffer.asUint8List(model.offsetInBytes, model.lengthInBytes),
          ]),
          'scale': scale,
        },
        onError: errors.sendPort,
        onExit: exits.sendPort,
      );
      if (_canceled) cancel();
      return await _result!.future;
    } finally {
      _worker?.kill(priority: Isolate.immediate);
      _worker = null;
      await subscription.cancel();
      await errorSubscription.cancel();
      await exitSubscription.cancel();
      messages.close();
      errors.close();
      exits.close();
    }
  }

  void cancel() {
    _canceled = true;
    _control?.send(true);
  }
}

Future<void> _enhance(Map<String, dynamic> request) async {
  final reply = request['reply'] as SendPort;
  Interpreter? interpreter;
  final elapsed = Stopwatch()..start();
  final control = ReceivePort();
  bool canceled = false;
  final controls = control.listen((_) => canceled = true);
  reply.send(control.sendPort);
  Object? response;

  try {
    final bytes = (request['image'] as TransferableTypedData)
        .materialize()
        .asUint8List();
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null) throw StateError('Select a supported JPG or PNG photo.');
    if (info.width * info.height > 25000000) {
      throw StateError('Use a photo below 25 megapixels.');
    }
    final decoded = decoder!.decodeFrame(0);
    if (decoded == null) throw StateError('Could not decode this photograph.');
    var image = img.bakeOrientation(decoded).convert(numChannels: 3);
    if (math.max(image.width, image.height) > 512) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? 512 : null,
        height: image.height > image.width ? 512 : null,
        interpolation: img.Interpolation.average,
      );
    }
    final model = (request['model'] as TransferableTypedData)
        .materialize()
        .asUint8List();
    final settings = InterpreterOptions()
      ..threads = math.min(4, Platform.numberOfProcessors);
    try {
      interpreter = Interpreter.fromBuffer(model, options: settings);
    } finally {
      settings.delete();
    }
    final input = interpreter.getInputTensor(0);
    final output = interpreter.getOutputTensor(0);
    if (input.shape.join(',') != '1,50,50,3' ||
        output.shape.join(',') != '1,200,200,3' ||
        input.type != TensorType.float32 ||
        output.type != TensorType.float32) {
      throw StateError('The bundled AI model is incompatible.');
    }
    const tile = 50, border = 4, core = tile - border * 2, factor = 4;
    final result = img.Image(
      width: image.width * factor,
      height: image.height * factor,
      numChannels: 3,
    );
    final source = Float32List(tile * tile * 3);
    final columns = (image.width / core).ceil(),
        rows = (image.height / core).ceil();
    var finished = 0;
    for (var top = 0; top < image.height; top += core) {
      for (var left = 0; left < image.width; left += core) {
        await Future<void>.delayed(Duration.zero);
        if (canceled) throw StateError('Task canceled.');
        if (elapsed.elapsed > const Duration(seconds: 90)) {
          throw StateError('Enhancement took too long.');
        }
        for (var y = 0; y < tile; y++) {
          for (var x = 0; x < tile; x++) {
            final pixel = image.getPixel(
              (left + x - border).clamp(0, image.width - 1),
              (top + y - border).clamp(0, image.height - 1),
            );
            final offset = (y * tile + x) * 3;
            source[offset] = pixel.r.toDouble();
            source[offset + 1] = pixel.g.toDouble();
            source[offset + 2] = pixel.b.toDouble();
          }
        }
        input.setTo(source.buffer.asUint8List());
        interpreter.invoke();
        final values = output.data.buffer.asFloat32List();
        final height = math.min(core, image.height - top) * factor;
        final width = math.min(core, image.width - left) * factor;
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final index =
                ((y + border * factor) * 200 + x + border * factor) * 3;
            result.setPixelRgb(
              left * factor + x,
              top * factor + y,
              values[index].round().clamp(0, 255),
              values[index + 1].round().clamp(0, 255),
              values[index + 2].round().clamp(0, 255),
            );
          }
        }
        reply.send(++finished / (columns * rows));
      }
    }
    final scale = request['scale'] as int;
    final finalImage = scale == 4
        ? result
        : img.copyResize(
            result,
            width: image.width * 2,
            height: image.height * 2,
            interpolation: img.Interpolation.average,
          );
    response = TransferableTypedData.fromList([img.encodePng(finalImage)]);
  } catch (_) {
    response = canceled
        ? 'Task canceled.'
        : 'On-device AI could not enhance this photo. Try a smaller photo or turn off AI for basic enhancement.';
  } finally {
    interpreter?.close();
    await controls.cancel();
    control.close();
  }
  reply.send(response);
}
