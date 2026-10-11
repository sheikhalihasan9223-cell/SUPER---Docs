import 'dart:typed_data';

const supportsDeviceAi = false;

class DeviceEnhancementTask {
  Future<Uint8List> run(
    Uint8List bytes,
    int scale, {
    void Function(double)? onProgress,
  }) async {
    throw UnsupportedError(
      'On-device AI is available on Android and iOS. Use basic enhancement here.',
    );
  }

  void cancel() {}
}
