import 'dart:convert';
import 'dart:io';

import 'package:typed_cache/typed_cache.dart';
import 'package:typed_cache_json/src/json_models.dart';
import 'package:typed_cache_json/src/json_utils.dart';

import 'async_mutex.dart';
import 'flutter_path.dart'; // 👈 novo

final class JsonFileCacheBackend implements CacheBackend {
  final File file;
  final AsyncMutex _mutex = AsyncMutex();

  /// If true, attempts recovery from .bak or .tmp when main file is corrupt.
  final bool enableRecovery;

  JsonFileCacheBackend({required this.file, this.enableRecovery = true});

  @override
  Future<void> clear() => _mutex.synchronized(() async {
    final db = JsonCacheFile.empty();
    await _save(db);
  });

  @override
  Future<void> delete(String key) => _mutex.synchronized(() async {
    final db = await _load();
    final removed = db.entries.remove(key);
    if (removed != null) {
      _removeKeyFromTags(db, key, removed.tags);
      await _save(db);
    }
  });

  @override
  Future<void> deleteTag(String tag) => _mutex.synchronized(() async {
    final db = await _load();
    final keys = db.tagIndex.remove(tag);
    if (keys == null || keys.isEmpty) return;

    for (final k in keys) {
      final entry = db.entries[k];
      if (entry == null) continue;
      final newTags = Set<String>.from(entry.tags)..remove(tag);
      db.entries[k] = entry.copyWith(tags: newTags) as CacheEntry<Map<String, dynamic>>;
    }

    await _save(db);
  });

  @override
  Future<Set<String>> keysByTag(String tag) => _mutex.synchronized(() async {
    final db = await _load();
    return Set<String>.from(db.tagIndex[tag] ?? const {});
  });

  @override
  Future<int> purgeExpired(int nowEpochMs) => _mutex.synchronized(() async {
    final db = await _load();
    final toRemove = <String>[];

    for (final e in db.entries.entries) {
      if (e.value.isExpired(nowEpochMs)) toRemove.add(e.key);
    }

    for (final key in toRemove) {
      final entry = db.entries.remove(key);
      if (entry != null) _removeKeyFromTags(db, key, entry.tags);
    }

    if (toRemove.isNotEmpty) await _save(db);
    return toRemove.length;
  });

  @override
  Future<CacheEntry<E>?> read<E>(String key) => _mutex.synchronized(() async {
    final db = await _load();
    return db.entries[key] as CacheEntry<E>?;
  });

  @override
  Future<void> write<E>(CacheEntry<E> entry) => _mutex.synchronized(() async {
    final db = await _load();
    _upsertEntry(db, entry);
    await _save(db);
  });

  Future<void> _atomicWrite(File target, String content) async {
    final dir = target.parent;
    if (!await dir.exists()) await dir.create(recursive: true);

    final tmp = File('${target.path}.tmp');
    final bak = File('${target.path}.bak');

    final raf = await tmp.open(mode: FileMode.write);
    try {
      await raf.writeString(content);
      await raf.flush();
    } finally {
      await raf.close();
    }

    if (await target.exists()) {
      try {
        await target.copy(bak.path);
      } catch (_) {}
    }

    try {
      await tmp.rename(target.path);
    } catch (_) {
      try {
        if (await target.exists()) await target.delete();
      } catch (_) {}
      await tmp.rename(target.path);
    }
  }

  Future<JsonCacheFile<Map<String, dynamic>>> _load() async {
    try {
      if (!await file.exists()) return JsonCacheFile.empty();

      final text = await file.readAsString();
      if (text.trim().isEmpty) return JsonCacheFile.empty();

      final decoded = jsonDecode(text);
      if (decoded is! Map) return JsonCacheFile.empty();

      return JsonCacheFile.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      if (!enableRecovery) return JsonCacheFile.empty();
      return _recoverOrEmpty();
    }
  }

  Future<JsonCacheFile<Map<String, dynamic>>> _recoverOrEmpty() async {
    final bak = File('${file.path}.bak');
    final tmp = File('${file.path}.tmp');

    for (final candidate in [bak, tmp]) {
      try {
        if (!await candidate.exists()) continue;
        final text = await candidate.readAsString();
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          final db = JsonCacheFile.fromJson(Map<String, dynamic>.from(decoded));
          await _atomicWrite(file, jsonEncode(db.toJson()));
          return db;
        }
      } catch (_) {}
    }
    return JsonCacheFile.empty();
  }

  void _removeKeyFromTags(JsonCacheFile db, String key, Set<String> tags) {
    for (final tag in tags) {
      final set = db.tagIndex[tag];
      if (set == null) continue;
      set.remove(key);
      if (set.isEmpty) db.tagIndex.remove(tag);
    }
  }

  Future<void> _save(JsonCacheFile db) async {
    final content = jsonEncode(db.toJson());
    await _atomicWrite(file, content);
  }

  // ---------- internals ----------

  void _upsertEntry(JsonCacheFile db, CacheEntry entry) {
    final previous = db.entries[entry.key];
    if (previous != null) _removeKeyFromTags(db, entry.key, previous.tags);

    db.entries[entry.key] = entry;

    for (final tag in entry.tags) {
      (db.tagIndex[tag] ??= <String>{}).add(entry.key);
    }
  }

  /// Flutter-friendly factory: resolves path via path_provider.
  static Future<JsonFileCacheBackend> fromLocation({
    CacheLocation location = CacheLocation.support,
    String fileName = 'typed_cache.json',
    String? subdir, // ex: 'typed_cache'
    bool enableRecovery = true,
  }) async {
    final f = await resolveCacheFile(location: location, fileName: fileName, subdir: subdir);

    return JsonFileCacheBackend(file: f, enableRecovery: enableRecovery);
  }
}
