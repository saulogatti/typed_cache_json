Beleza. Vamos colocar **limite de tamanho + eviction** no JSON sem transformar isso num banco de dados (ainda).

O problema: pra eviction decente você precisa de **critério** (FIFO/LRU) e de uma forma de estimar **tamanho real** do arquivo. Como é JSON em arquivo único, o tamanho “real” que importa é o **bytes do JSON final** (UTF-8).

### Decisões práticas (pra não virar novela)

* **maxBytes**: limite do arquivo em bytes (UTF-8 do JSON).
* **EvictionStrategy**:

  * `fifo`: remove os mais antigos (`createdAt`) → simples, sem regravar em todo `get`.
  * `lru`: remove os menos acessados → precisa registrar `lastAccessAt`, o que pode implicar salvar arquivo em leituras (caro).
* Eu vou te dar os dois, com `fifo` como default “sensato”.

---

# 1) Atualize `json_models.dart` pra incluir accessIndex

**typed_cache_json/lib/src/json_models.dart**

```dart
import 'package:typed_cache/typed_cache.dart';

Map<String, Object?> entryToJson(CacheEntry e) => <String, Object?>{
      'key': e.key,
      'typeId': e.typeId,
      'payload': e.payload,
      'createdAt': e.createdAtEpochMs,
      'expiresAt': e.expiresAtEpochMs,
      'tags': e.tags.toList(growable: false),
    };

CacheEntry entryFromJson(Map<String, Object?> json) => CacheEntry(
      key: json['key'] as String,
      typeId: json['typeId'] as String,
      payload: json['payload'] as Object,
      createdAtEpochMs: (json['createdAt'] as num).toInt(),
      expiresAtEpochMs: (json['expiresAt'] as num?)?.toInt(),
      tags: ((json['tags'] as List?) ?? const [])
          .map((e) => e as String)
          .toSet(),
    );

final class JsonCacheFile {
  final int schemaVersion;
  final Map<String, CacheEntry> entries;
  final Map<String, Set<String>> tagIndex;

  /// For LRU (key -> lastAccessAtEpochMs).
  final Map<String, int> accessIndex;

  const JsonCacheFile({
    required this.schemaVersion,
    required this.entries,
    required this.tagIndex,
    required this.accessIndex,
  });

  static const int currentSchemaVersion = 2;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'entries': entries.map((k, v) => MapEntry(k, entryToJson(v))),
        'tagIndex': tagIndex.map((tag, keys) => MapEntry(tag, keys.toList())),
        'accessIndex': accessIndex,
      };

  static JsonCacheFile empty() => const JsonCacheFile(
        schemaVersion: currentSchemaVersion,
        entries: {},
        tagIndex: {},
        accessIndex: {},
      );

  static JsonCacheFile fromJson(Map<String, Object?> json) {
    final schema = (json['schemaVersion'] as num?)?.toInt() ?? 1;

    final entriesRaw = (json['entries'] as Map?) ?? const {};
    final entries = <String, CacheEntry>{};
    for (final MapEntry(:key, :value) in entriesRaw.entries) {
      entries[key as String] =
          entryFromJson(Map<String, Object?>.from(value as Map));
    }

    final tagRaw = (json['tagIndex'] as Map?) ?? const {};
    final tagIndex = <String, Set<String>>{};
    for (final MapEntry(:key, :value) in tagRaw.entries) {
      tagIndex[key as String] =
          (value as List).map((e) => e as String).toSet();
    }

    final accessRaw = (json['accessIndex'] as Map?) ?? const {};
    final accessIndex = <String, int>{};
    for (final MapEntry(:key, :value) in accessRaw.entries) {
      accessIndex[key as String] = (value as num).toInt();
    }

    // Migrate: schema < 2 => create empty accessIndex (best effort).
    if (schema < 2) {
      // optionally seed with createdAt to approximate LRU.
      for (final e in entries.entries) {
        accessIndex[e.key] = e.value.createdAtEpochMs;
      }
    }

    return JsonCacheFile(
      schemaVersion: currentSchemaVersion,
      entries: entries,
      tagIndex: tagIndex,
      accessIndex: accessIndex,
    );
  }
}
```

---

# 2) Adicione estratégia e opções no backend

**typed_cache_json/lib/src/json_file_cache_backend.dart** (mudanças relevantes)

```dart
import 'dart:convert';
import 'dart:io';

import 'package:typed_cache/typed_cache.dart';

import 'async_mutex.dart';
import 'json_models.dart';
import 'flutter_path.dart';

enum EvictionStrategy { fifo, lru }

final class JsonFileCacheBackend implements CacheBackend {
  final File file;
  final AsyncMutex _mutex = AsyncMutex();

  final bool enableRecovery;

  /// Max size of the JSON file (UTF-8 bytes). Null => unlimited.
  final int? maxBytes;

  /// FIFO (createdAt) or LRU (lastAccessAt).
  final EvictionStrategy evictionStrategy;

  /// If true and strategy is LRU, a read updates accessIndex and persists it,
  /// which can cause frequent file writes.
  final bool persistAccessOnRead;

  /// Prevent thrashing: when exceeding maxBytes, evict until <= maxBytes * targetFillRatio.
  final double targetFillRatio;

  JsonFileCacheBackend({
    required this.file,
    this.enableRecovery = true,
    this.maxBytes,
    this.evictionStrategy = EvictionStrategy.fifo,
    this.persistAccessOnRead = false,
    this.targetFillRatio = 0.9,
  }) : assert(targetFillRatio > 0 && targetFillRatio <= 1.0);

  static Future<JsonFileCacheBackend> fromLocation({
    CacheLocation location = CacheLocation.support,
    String fileName = 'typed_cache.json',
    String? subdir,
    bool enableRecovery = true,
    int? maxBytes,
    EvictionStrategy evictionStrategy = EvictionStrategy.fifo,
    bool persistAccessOnRead = false,
    double targetFillRatio = 0.9,
  }) async {
    final f = await resolveCacheFile(
      location: location,
      fileName: fileName,
      subdir: subdir,
    );

    return JsonFileCacheBackend(
      file: f,
      enableRecovery: enableRecovery,
      maxBytes: maxBytes,
      evictionStrategy: evictionStrategy,
      persistAccessOnRead: persistAccessOnRead,
      targetFillRatio: targetFillRatio,
    );
  }

  @override
  Future<void> write(CacheEntry entry) => _mutex.synchronized(() async {
        final db = await _load();

        _upsertEntry(db, entry);

        // Touch access for LRU even on write.
        final now = DateTime.now().millisecondsSinceEpoch;
        db.accessIndex[entry.key] = now;

        await _enforceAndSave(db);
      });

  @override
  Future<CacheEntry?> read(String key) => _mutex.synchronized(() async {
        final db = await _load();
        final entry = db.entries[key];
        if (entry == null) return null;

        if (evictionStrategy == EvictionStrategy.lru) {
          db.accessIndex[key] = DateTime.now().millisecondsSinceEpoch;
          if (persistAccessOnRead) {
            await _enforceAndSave(db); // writes file (expensive)
          }
        }
        return entry;
      });

  @override
  Future<void> delete(String key) => _mutex.synchronized(() async {
        final db = await _load();
        final removed = db.entries.remove(key);
        db.accessIndex.remove(key);
        if (removed != null) {
          _removeKeyFromTags(db, key, removed.tags);
          await _enforceAndSave(db);
        }
      });

  @override
  Future<void> clear() => _mutex.synchronized(() async {
        final db = JsonCacheFile.empty();
        await _save(db);
      });

  @override
  Future<Set<String>> keysByTag(String tag) => _mutex.synchronized(() async {
        final db = await _load();
        return Set<String>.from(db.tagIndex[tag] ?? const {});
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
          db.entries[k] = entry.copyWith(tags: newTags);
        }

        await _enforceAndSave(db);
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
          db.accessIndex.remove(key);
          if (entry != null) _removeKeyFromTags(db, key, entry.tags);
        }

        if (toRemove.isNotEmpty) {
          await _enforceAndSave(db);
        } else if (maxBytes != null) {
          // still enforce in case file grew via accessIndex etc.
          await _enforceAndSave(db);
        }

        return toRemove.length;
      });

  // ---------- enforcement ----------

  Future<void> _enforceAndSave(JsonCacheFile db) async {
    if (maxBytes == null) {
      await _save(db);
      return;
    }

    // First: purge expired (cheap win).
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiredKeys = <String>[];
    for (final e in db.entries.entries) {
      if (e.value.isExpired(now)) expiredKeys.add(e.key);
    }
    for (final k in expiredKeys) {
      final entry = db.entries.remove(k);
      db.accessIndex.remove(k);
      if (entry != null) _removeKeyFromTags(db, k, entry.tags);
    }

    // Then: eviction until under target.
    final limit = maxBytes!;
    final target = (limit * targetFillRatio).floor();

    int size = _estimateSizeBytes(db);
    if (size <= limit) {
      await _save(db);
      return;
    }

    // Sort candidate keys by strategy.
    final keys = db.entries.keys.toList(growable: false);
    keys.sort((a, b) {
      final ea = db.entries[a]!;
      final eb = db.entries[b]!;
      return switch (evictionStrategy) {
        EvictionStrategy.fifo =>
          ea.createdAtEpochMs.compareTo(eb.createdAtEpochMs),
        EvictionStrategy.lru => (db.accessIndex[a] ?? ea.createdAtEpochMs)
            .compareTo(db.accessIndex[b] ?? eb.createdAtEpochMs),
      };
    });

    // Evict oldest until <= target (hysteresis avoids thrash).
    for (final k in keys) {
      if (size <= target) break;
      final entry = db.entries.remove(k);
      db.accessIndex.remove(k);
      if (entry != null) _removeKeyFromTags(db, k, entry.tags);
      size = _estimateSizeBytes(db);
    }

    await _save(db);
  }

  int _estimateSizeBytes(JsonCacheFile db) {
    // Realistic: size of the actual JSON that will be written.
    // It's O(n), but JSON backend is already O(n) by nature. Deal with it.
    final jsonStr = jsonEncode(db.toJson());
    return utf8.encode(jsonStr).length;
  }

  // ---------- internals unchanged-ish (but update to handle accessIndex) ----------

  void _upsertEntry(JsonCacheFile db, CacheEntry entry) {
    final previous = db.entries[entry.key];
    if (previous != null) _removeKeyFromTags(db, entry.key, previous.tags);

    db.entries[entry.key] = entry;

    for (final tag in entry.tags) {
      (db.tagIndex[tag] ??= <String>{}).add(entry.key);
    }
  }

  void _removeKeyFromTags(JsonCacheFile db, String key, Set<String> tags) {
    for (final tag in tags) {
      final set = db.tagIndex[tag];
      if (set == null) continue;
      set.remove(key);
      if (set.isEmpty) db.tagIndex.remove(tag);
    }
  }

  Future<JsonCacheFile> _load() async {
    try {
      if (!await file.exists()) return JsonCacheFile.empty();
      final text = await file.readAsString();
      if (text.trim().isEmpty) return JsonCacheFile.empty();

      final decoded = jsonDecode(text);
      if (decoded is! Map) return JsonCacheFile.empty();

      return JsonCacheFile.fromJson(Map<String, Object?>.from(decoded as Map));
    } catch (_) {
      if (!enableRecovery) return JsonCacheFile.empty();
      return _recoverOrEmpty();
    }
  }

  Future<JsonCacheFile> _recoverOrEmpty() async {
    final bak = File('${file.path}.bak');
    final tmp = File('${file.path}.tmp');

    for (final candidate in [bak, tmp]) {
      try {
        if (!await candidate.exists()) continue;
        final text = await candidate.readAsString();
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          final db = JsonCacheFile.fromJson(Map<String, Object?>.from(decoded));
          await _atomicWrite(file, jsonEncode(db.toJson()));
          return db;
        }
      } catch (_) {}
    }
    return JsonCacheFile.empty();
  }

  Future<void> _save(JsonCacheFile db) async {
    final content = jsonEncode(db.toJson());
    await _atomicWrite(file, content);
  }

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
}
```

---

# 3) Como usar no Flutter

```dart
final backend = await JsonFileCacheBackend.fromLocation(
  location: CacheLocation.support,
  subdir: 'typed_cache',
  fileName: 'cache.json',
  maxBytes: 2 * 1024 * 1024, // 2MB
  evictionStrategy: EvictionStrategy.fifo, // ou lru
  persistAccessOnRead: false, // true só se você aceitar writes em reads
);

final cache = CacheStore(backend: backend);
```

---

## Recomendações (pra você não fazer besteira)

* **Comece com `fifo`**. LRU “real” em JSON de arquivo único vira “escreve arquivo pra cada get” se você persistir acessos.
* Se você quer LRU de verdade sem dor: **SQLite** (logo logo você vai querer).
* `targetFillRatio=0.9` evita ficar evictando 1 item por vez a cada escrita (thrashing).

Pronto: agora seu “cache” tem limite e não vai crescer até consumir a alma do app.
Próximo passo: você vai medir o impacto do `jsonEncode` O(n) a cada escrita, ou vai fingir que performance é um detalhe “do futuro”? 😏
