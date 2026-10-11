import 'dart:convert';
import 'dart:async';
import 'cloud_backend.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'file_storage.dart';

class AppStore extends ChangeNotifier {
  final SharedPreferences prefs;
  final CloudDocuments? cloud;
  String? accountId;
  int epoch = 0;
  bool syncing = false;
  String? syncError;
  final Set<String> dirty = {}, deleted = {};
  final Map<String, int> revisions = {};
  String get catalogKey => accountId == null ? 'files' : 'files:$accountId';
  String diskId(String id, [String? owner]) =>
      owner == null ? id : '$owner::$id';
  Map<String, String> get remoteHeaders {
    final backend = SupabaseBackend.active;
    if (backend == null) return {};
    final token = backend.token;
    if (token == null) {
      throw StateError('Sign in with Google to use cloud processing.');
    }
    return {'Authorization': 'Bearer $token', 'apikey': backend.publicKey};
  }

  FileStorage? storage;
  Future<void> pending = Future<void>.value();
  final List<DocFile> files = [];
  final Set<String> favorites = {};
  String get endpoint {
    final backend = SupabaseBackend.active;
    if (backend != null) return backend.functionEndpoint;
    const configured = String.fromEnvironment('PROCESSOR_URL');
    final saved = prefs.getString('endpoint');
    final value =
        saved ?? (configured.isNotEmpty ? configured : 'http://127.0.0.1:8000');
    // Android emulator loopback addresses point to Android, not the host PC.
    // Preserve explicit build configuration and other saved service addresses.
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        configured.isEmpty) {
      final uri = Uri.tryParse(value);
      if (uri != null &&
          uri.scheme == 'http' &&
          uri.port == 8000 &&
          ['127.0.0.1', 'localhost', '::1'].contains(uri.host)) {
        return uri.replace(host: '10.0.2.2').toString();
      }
    }
    return value;
  }

  bool get dark => prefs.getBool('dark') ?? false;
  AppStore(this.prefs, {this.cloud}) {
    favorites.addAll(
      prefs.getStringList('favorites') ??
          ['merge', 'compress', 'image_pdf', 'protect'],
    );
    try {
      for (final e in jsonDecode(prefs.getString('files') ?? '[]') as List) {
        files.add(
          DocFile(
            id: e['id'],
            name: e['name'],
            bytes: base64Decode(e['bytes']),
            created: DateTime.parse(e['created']),
            tool: e['tool'],
            favorite: e['favorite'] ?? false,
          ),
        );
      }
    } catch (_) {
      files.clear();
    }
  }
  Future<void> toggleTool(String id) async {
    favorites.contains(id) ? favorites.remove(id) : favorites.add(id);
    await prefs.setStringList('favorites', favorites.toList());
    notifyListeners();
  }

  Future<void> settings({String? endpoint, bool? dark}) async {
    if (endpoint != null) {
      await prefs.setString('endpoint', endpoint);
    }
    if (dark != null) {
      await prefs.setBool('dark', dark);
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    final disk = FileStorage();
    await disk.initialize();
    storage = disk;
    await switchAccount(force: true);
  }

  Future<void> switchAccount({bool force = false}) async {
    final owner = cloud?.userId;
    if (!force && owner == accountId) {
      notifyListeners();
      return;
    }
    final ticket = ++epoch;
    accountId = owner;
    files.clear();
    dirty.clear();
    deleted.clear();
    revisions.clear();
    syncError = null;
    notifyListeners();
    final key = catalogKey;
    dirty.addAll(prefs.getStringList('$key:dirty') ?? []);
    deleted.addAll(prefs.getStringList('$key:deleted') ?? []);
    final restored = <DocFile>[];
    final savedCatalog = jsonDecode(prefs.getString(key) ?? '[]');
    final catalog = savedCatalog is List
        ? savedCatalog
        : savedCatalog['files'] as List;
    if (savedCatalog is Map) {
      dirty
        ..clear()
        ..addAll(List<String>.from(savedCatalog['dirty'] ?? []));
      deleted
        ..clear()
        ..addAll(List<String>.from(savedCatalog['deleted'] ?? []));
    }
    for (final e in catalog) {
      try {
        final bytes = e['bytes'] != null
            ? base64Decode(e['bytes'])
            : await storage!.read(diskId(e['id'], owner));
        if (ticket != epoch) return;
        if (e['bytes'] != null && storage?.external == true) {
          await storage!.write(diskId(e['id'], owner), bytes);
        }
        if (ticket != epoch) return;
        restored.add(
          DocFile(
            id: e['id'],
            name: e['name'],
            bytes: bytes,
            created: DateTime.parse(e['created']),
            tool: e['tool'],
            favorite: e['favorite'] ?? false,
          ),
        );
      } catch (_) {
        if (e['bytes'] != null) rethrow;
      }
    }
    if (ticket != epoch) return;
    files.addAll(restored);
    await writeCatalog();
    if (ticket == epoch && owner != null) unawaited(sync());
  }

  Future<void> save(DocFile file) {
    final ticket = epoch;
    final owner = accountId;
    final operation = pending.then((_) async {
      if (ticket != epoch) {
        throw StateError('Your account changed. Please save the result again.');
      }
      await storage?.write(diskId(file.id, owner), file.bytes);
      if (ticket != epoch) {
        throw StateError('Your account changed. Please save the result again.');
      }
      final previous = List<DocFile>.of(files);
      files.removeWhere((f) => f.id == file.id);
      files.insert(0, file);
      dirty.add(file.id);
      deleted.remove(file.id);
      revisions.update(file.id, (v) => v + 1, ifAbsent: () => 1);
      try {
        await writeCatalog();
        if (owner != null && ticket == epoch) unawaited(sync());
      } catch (_) {
        files
          ..clear()
          ..addAll(previous);
        rethrow;
      }
    });
    pending = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> persist() async {
    for (final file in files) {
      dirty.add(file.id);
      revisions.update(file.id, (v) => v + 1, ifAbsent: () => 1);
    }
    await writeCatalog();
    if (accountId != null) unawaited(sync());
  }

  Future<void> writeCatalog() async {
    final key = catalogKey;
    final pendingIds = dirty.toList(), deletedIds = deleted.toList();
    final entries = files
        .map(
          (f) => {
            'id': f.id,
            'name': f.name,
            if (storage?.external != true) 'bytes': base64Encode(f.bytes),
            'created': f.created.toIso8601String(),
            'tool': f.tool,
            'favorite': f.favorite,
          },
        )
        .toList();
    // Cloud catalog and pending operations commit in the same preference write.
    final payload = accountId == null
        ? entries
        : {'files': entries, 'dirty': pendingIds, 'deleted': deletedIds};
    final written = await prefs.setString(key, jsonEncode(payload));
    if (!written) {
      throw StateError(
        'Could not save this file. Free some storage and retry.',
      );
    }
    await prefs.setStringList('$key:dirty', pendingIds);
    await prefs.setStringList('$key:deleted', deletedIds);
    notifyListeners();
  }

  Future<void> remove(DocFile file) async {
    final owner = accountId;
    files.removeWhere((f) => f.id == file.id);
    dirty.remove(file.id);
    deleted.add(file.id);
    await writeCatalog();
    await storage?.delete(diskId(file.id, owner));
    if (owner != null) unawaited(sync());
  }

  Future<void> sync() async {
    final owner = accountId;
    if (cloud == null || owner == null || syncing || cloud!.userId != owner) {
      return;
    }
    final ticket = epoch;
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      for (final id in Set<String>.of(deleted)) {
        await cloud!.remove(owner, id);
        if (ticket != epoch) return;
        deleted.remove(id);
      }
      for (final id in Set<String>.of(dirty)) {
        final matching = files.where((f) => f.id == id);
        if (matching.isEmpty) {
          dirty.remove(id);
          continue;
        }
        final f = matching.first;
        final version = revisions[id];
        final snapshot = DocFile(
          id: f.id,
          name: f.name,
          bytes: f.bytes,
          created: f.created,
          tool: f.tool,
          favorite: f.favorite,
        );
        await cloud!.save(owner, snapshot);
        if (ticket != epoch) return;
        if (revisions[id] == version) dirty.remove(id);
      }
      final remote = await cloud!.list(
        owner,
        cached: {for (final f in files) f.id: f},
      );
      if (ticket != epoch) return;
      final remoteIds = remote.map((f) => f.id).toSet();
      final removed = files
          .where((f) => !remoteIds.contains(f.id) && !dirty.contains(f.id))
          .toList();
      for (final f in removed) {
        await storage?.delete(diskId(f.id, owner));
        if (ticket != epoch) return;
        files.removeWhere((local) => local.id == f.id);
      }
      for (final f in remote) {
        if (dirty.contains(f.id) || deleted.contains(f.id)) continue;
        if (!files.any((local) => local.id == f.id)) {
          await storage?.write(diskId(f.id, owner), f.bytes);
        }
        if (ticket != epoch) return;
        files.removeWhere((local) => local.id == f.id);
        files.add(f);
      }
      files.sort((a, b) => b.created.compareTo(a.created));
      await writeCatalog();
    } catch (_) {
      if (ticket == epoch) {
        syncError =
            'Cloud sync failed. Your device copies are safe. Try again when online.';
        try {
          await writeCatalog();
        } catch (_) {
          /* Keep the retry state in memory. */
        }
      }
    } finally {
      syncing = false;
      notifyListeners();
      if (accountId != null &&
          (ticket != epoch ||
              syncError == null && (dirty.isNotEmpty || deleted.isNotEmpty))) {
        unawaited(sync());
      }
    }
  }
}
