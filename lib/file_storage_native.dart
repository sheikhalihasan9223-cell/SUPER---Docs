import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class FileStorage {
  late Directory directory;
  bool get external => true;
  Future<void> initialize() async {
    final root = await getApplicationSupportDirectory();
    directory = await Directory(
      '${root.path}/documents',
    ).create(recursive: true);
  }

  File file(String id) {
    // Catalog IDs never become arbitrary filesystem paths.
    final safe = Uri.encodeComponent(id).replaceAll('.', '%2E');
    return File('${directory.path}/$safe.bin');
  }

  Future<void> write(String id, Uint8List bytes) async {
    final temporary = File('${file(id).path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file(id).path);
  }

  Future<Uint8List> read(String id) => file(id).readAsBytes();
  Future<void> delete(String id) async {
    final target = file(id);
    if (await target.exists()) await target.delete();
  }
}

Future<void> openSavedFile(String name, Uint8List bytes) async {
  final root = await getTemporaryDirectory();
  final folder = await Directory(
    '${root.path}/document-preview',
  ).create(recursive: true);
  final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_');
  final target = File('${folder.path}/$safeName');
  await target.writeAsBytes(bytes, flush: true);
  final result = await OpenFilex.open(target.path);
  if (result.type != ResultType.done) throw StateError(result.message);
}
