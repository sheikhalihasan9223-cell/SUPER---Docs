import 'dart:typed_data';

// Browsers persist bytes with the catalog in local storage.
class FileStorage {
  bool get external => false;
  Future<void> initialize() async {}
  Future<void> write(String id, Uint8List bytes) async {}
  Future<Uint8List> read(String id) async =>
      throw UnsupportedError('Inline storage');
  Future<void> delete(String id) async {}
}

Future<void> openSavedFile(String name, Uint8List bytes) async {
  throw UnsupportedError('Download this file to open it in a compatible app.');
}
