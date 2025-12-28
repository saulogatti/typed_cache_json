import 'dart:convert';
import 'dart:io';

import 'package:typed_cache/typed_cache.dart';
import 'package:typed_cache_json/src/json_models.dart';
import 'package:typed_cache_json/src/json_utils.dart';

import 'async_mutex.dart';
import 'flutter_path.dart';

/// A [CacheBackend] implementation that stores cache data in a JSON file.
///
/// This backend provides persistent storage with several key features:
///
/// ## Key Features
///
/// - **Atomic Writes**: Uses temporary and backup files to prevent corruption
/// - **Auto-Recovery**: Falls back to backup files if main file is corrupted
/// - **Thread-Safe**: All operations protected by [AsyncMutex]
/// - **Tag Indexing**: Maintains reverse index for efficient tag operations
/// - **Type-Safe**: Generic over payload type [E]
///
/// ## File Safety Mechanism
///
/// During writes, three files are used:
/// - `cache.json` - Main cache file
/// - `cache.json.tmp` - Temporary file for atomic writes
/// - `cache.json.bak` - Backup of previous version for recovery
///
/// Write sequence:
/// 1. Write new data to `.tmp`
/// 2. Copy current file to `.bak`
/// 3. Rename `.tmp` to main file (atomic operation)
///
/// ## Recovery Mechanism
///
/// If the main file is corrupted and [enableRecovery] is true:
/// 1. Try to load from `.bak` file
/// 2. If that fails, try `.tmp` file
/// 3. If all fail, start with empty cache
///
/// ## Usage
///
/// Typically created via [fromLocation] factory method:
///
/// ```dart
/// final backend = await JsonFileCacheBackend.fromLocation(
///   location: CacheLocation.support,
///   fileName: 'cache.json',
///   enableRecovery: true,
/// );
///
/// // Use with TypedCache
/// final cache = createTypedCache(backend: backend);
/// ```
///
/// ## Concurrency
///
/// All public methods are serialized through an internal mutex, ensuring
/// that concurrent operations don't corrupt the file or internal state.
final class JsonFileCacheBackend implements CacheBackend {
  /// The cache file location on disk.
  final File file;

  /// Internal mutex to serialize all cache operations.
  final AsyncMutex _mutex = AsyncMutex();

  /// If true, attempts recovery from .bak or .tmp when main file is corrupt.
  ///
  /// When false, a corrupted main file results in an empty cache.
  final bool enableRecovery;

  /// Creates a backend pointing to the specified [file].
  ///
  /// ## Parameters
  ///
  /// - [file]: The JSON file for storing cache data
  /// - [enableRecovery]: Whether to attempt recovery from backup files (default: true)
  ///
  /// **Recommendation**: Use [fromLocation] factory instead for Flutter apps.
  JsonFileCacheBackend({required this.file, this.enableRecovery = true});

  /// Removes all entries from the cache.
  ///
  /// This operation:
  /// 1. Creates an empty cache structure
  /// 2. Writes it to disk using atomic write
  /// 3. Clears both entries and tag index
  ///
  /// ## Thread Safety
  ///
  /// Serialized through internal mutex - safe to call concurrently.
  @override
  Future<void> clear() => _mutex.synchronized(() async {
    final db = JsonCacheFile.empty();
    await _save(db);
  });

  /// Deletes a single entry from the cache by key.
  ///
  /// This operation:
  /// 1. Loads the current cache state
  /// 2. Removes the entry if it exists
  /// 3. Updates the tag index to remove the key from all associated tags
  /// 4. Writes the updated cache to disk
  ///
  /// ## Parameters
  ///
  /// - [key]: The cache key to delete
  ///
  /// ## Behavior
  ///
  /// If the key doesn't exist, this is a no-op (no file write occurs).
  ///
  /// ## Thread Safety
  ///
  /// Serialized through internal mutex - safe to call concurrently.
  @override
  Future<void> delete(String key) => _mutex.synchronized(() async {
    final db = await _load();
    final removed = db.entries.remove(key);
    if (removed != null) {
      _removeKeyFromTags(db, key, removed.tags);
      await _save(db);
    }
  });

  /// Deletes a tag and removes it from all entries.
  ///
  /// This operation:
  /// 1. Removes the tag from the tag index
  /// 2. Updates all entries that had this tag, removing it from their tag sets
  /// 3. Writes the updated cache to disk
  ///
  /// ## Parameters
  ///
  /// - [tag]: The tag to delete
  ///
  /// ## Behavior
  ///
  /// - If the tag doesn't exist, this is a no-op
  /// - Entries that had this tag are kept, only the tag is removed from them
  /// - The tag index entry is completely removed
  ///
  /// ## Thread Safety
  ///
  /// Serialized through internal mutex - safe to call concurrently.
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

    await _save(db);
  });

  /// Returns all keys that have the specified tag.
  ///
  /// This operation uses the reverse tag index for O(1) lookup.
  ///
  /// ## Parameters
  ///
  /// - [tag]: The tag to search for
  ///
  /// ## Returns
  ///
  /// A set of cache keys that have the specified tag.
  /// Returns an empty set if the tag doesn't exist.
  ///
  /// ## Thread Safety
  ///
  /// Serialized through internal mutex - safe to call concurrently.
  @override
  Future<Set<String>> keysByTag(String tag) => _mutex.synchronized(() async {
    final db = await _load();
    return Set<String>.from(db.tagIndex[tag] ?? const {});
  });

  /// Removes all expired entries from the cache.
  ///
  /// This operation:
  /// 1. Scans all entries for expired items (based on [nowEpochMs])
  /// 2. Removes expired entries
  /// 3. Updates the tag index
  /// 4. Writes to disk only if entries were removed
  ///
  /// ## Parameters
  ///
  /// - [nowEpochMs]: Current time in milliseconds since epoch for comparison
  ///
  /// ## Returns
  ///
  /// The number of entries that were removed.
  ///
  /// ## Usage
  ///
  /// ```dart
  /// final removed = await backend.purgeExpired(
  ///   DateTime.now().millisecondsSinceEpoch,
  /// );
  /// print('Purged $removed expired entries');
  /// ```
  ///
  /// ## Thread Safety
  ///
  /// Serialized through internal mutex - safe to call concurrently.
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

  /// Reads a single cache entry by key.
  ///
  /// ## Parameters
  ///
  /// - [key]: The cache key to read
  ///
  /// ## Type Parameter
  ///
  /// - [E]: The payload type for the entry
  ///
  /// ## Returns
  ///
  /// The [CacheEntry] if found, or `null` if the key doesn't exist.
  ///
  /// ## Notes
  ///
  /// - Does not check expiration - the caller (TypedCache) handles that
  /// - Does not remove expired entries from disk automatically
  ///
  /// ## Thread Safety
  ///
  /// Serialized through internal mutex - safe to call concurrently.
  @override
  Future<CacheEntry<E>?> read<E>(String key) => _mutex.synchronized(() async {
    final db = await _load<E>();
    return db.entries[key];
  });
  @override
  Future<List<CacheEntry<E>>> readAll<E>() async {
    final db = await _load<E>();
    return db.entries.values.toList();
  }

  /// Writes or updates a cache entry.
  ///
  /// This operation:
  /// 1. Loads the current cache state
  /// 2. If an entry with the same key exists, removes it from the tag index
  /// 3. Adds/updates the entry
  /// 4. Updates the tag index with the entry's tags
  /// 5. Writes to disk atomically
  ///
  /// ## Parameters
  ///
  /// - [entry]: The cache entry to write
  ///
  /// ## Type Parameter
  ///
  /// - [E]: The payload type for the entry
  ///
  /// ## Thread Safety
  ///
  /// Serialized through internal mutex - safe to call concurrently.
  @override
  Future<void> write<E>(CacheEntry<E> entry) => _mutex.synchronized(() async {
    final db = await _load<E>();
    _upsertEntry(db, entry);
    await _save(db);
  });

  /// Performs an atomic write to the target file.
  ///
  /// This internal method implements the three-file write protocol:
  /// 1. Write content to `.tmp` file with proper fsync
  /// 2. Copy current file to `.bak` (if it exists)
  /// 3. Rename `.tmp` to target (atomic on most filesystems)
  ///
  /// ## Parameters
  ///
  /// - [target]: The final destination file
  /// - [content]: The JSON string to write
  ///
  /// ## Error Handling
  ///
  /// - Creates parent directories if they don't exist
  /// - If rename fails, deletes target and retries
  /// - Silently ignores backup copy errors (not critical)
  ///
  /// ## Throws
  ///
  /// May throw [FileSystemException] if unable to write or rename files.
  Future<void> _atomicWrite(File target, String content) async {
    final dir = target.parent;
    if (!await dir.exists()) await dir.create(recursive: true);

    final tmp = File('${target.path}.tmp');
    final bak = File('${target.path}.bak');

    // Write to temporary file with fsync
    final raf = await tmp.open(mode: FileMode.write);
    try {
      await raf.writeString(content);
      await raf.flush();
    } finally {
      await raf.close();
    }

    // Backup current file if it exists
    if (await target.exists()) {
      try {
        await target.copy(bak.path);
      } catch (_) {
        // Backup failure is not critical
      }
    }

    // Atomic rename (or delete + rename if first attempt fails)
    try {
      await tmp.rename(target.path);
    } catch (_) {
      try {
        if (await target.exists()) await target.delete();
      } catch (_) {}
      await tmp.rename(target.path);
    }
  }

  /// Loads the cache file from disk.
  ///
  /// This internal method:
  /// 1. Checks if file exists (returns empty if not)
  /// 2. Reads and parses the JSON content
  /// 3. Deserializes into [JsonCacheFile]
  /// 4. On error, attempts recovery if enabled, or returns empty
  ///
  /// ## Type Parameter
  ///
  /// - [E]: The payload type for entries
  ///
  /// ## Returns
  ///
  /// A [JsonCacheFile] with the loaded data, or an empty one if file
  /// doesn't exist or is corrupted.
  ///
  /// ## Recovery
  ///
  /// If [enableRecovery] is true and the main file is corrupted,
  /// calls [_recoverOrEmpty] to attempt loading from backup files.
  Future<JsonCacheFile<E>> _load<E>() async {
    try {
      if (!await file.exists()) return JsonCacheFile.empty<E>();

      final text = await file.readAsString();
      if (text.trim().isEmpty) return JsonCacheFile.empty<E>();

      final decoded = jsonDecode(text);
      if (decoded is! Map) return JsonCacheFile.empty<E>();

      return JsonCacheFile.fromJson<E>(Map<String, dynamic>.from(decoded));
    } catch (_) {
      if (!enableRecovery) return JsonCacheFile.empty<E>();
      return _recoverOrEmpty<E>();
    }
  }

  /// Attempts to recover the cache from backup files.
  ///
  /// This internal recovery method tries, in order:
  /// 1. Load from `.bak` file (previous version)
  /// 2. Load from `.tmp` file (possibly incomplete write)
  /// 3. Return empty cache if all fail
  ///
  /// If recovery succeeds from a backup, the main file is restored
  /// with the recovered data using atomic write.
  ///
  /// ## Type Parameter
  ///
  /// - [E]: The payload type for entries
  ///
  /// ## Returns
  ///
  /// A [JsonCacheFile] with recovered data, or an empty one if
  /// recovery fails.
  Future<JsonCacheFile<E>> _recoverOrEmpty<E>() async {
    final bak = File('${file.path}.bak');
    final tmp = File('${file.path}.tmp');

    for (final candidate in [bak, tmp]) {
      try {
        if (!await candidate.exists()) continue;
        final text = await candidate.readAsString();
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          final db = JsonCacheFile.fromJson<E>(Map<String, dynamic>.from(decoded));
          // Restore the main file with recovered data
          await _atomicWrite(file, jsonEncode(db.toJson()));
          return db;
        }
      } catch (_) {
        // Try next candidate
      }
    }
    return JsonCacheFile.empty<E>();
  }

  /// Removes a key from all specified tags in the tag index.
  ///
  /// This internal helper updates the reverse tag index when an entry
  /// is removed or updated.
  ///
  /// ## Parameters
  ///
  /// - [db]: The cache file to modify
  /// - [key]: The key to remove from tags
  /// - [tags]: The tags to remove the key from
  ///
  /// ## Behavior
  ///
  /// - If a tag becomes empty after removing the key, the tag is deleted
  /// - If a tag doesn't exist in the index, it's silently ignored
  void _removeKeyFromTags<E>(JsonCacheFile<E> db, String key, Set<String> tags) {
    for (final tag in tags) {
      final set = db.tagIndex[tag];
      if (set == null) continue;
      set.remove(key);
      if (set.isEmpty) db.tagIndex.remove(tag);
    }
  }

  /// Saves the cache to disk using atomic write.
  ///
  /// This internal helper serializes the [db] to JSON and writes it
  /// atomically using [_atomicWrite].
  ///
  /// ## Parameters
  ///
  /// - [db]: The cache file to save
  Future<void> _save(JsonCacheFile db) async {
    final content = jsonEncode(db.toJson());
    await _atomicWrite(file, content);
  }

  /// Inserts or updates an entry in the cache.
  ///
  /// This internal helper:
  /// 1. Removes the old entry from the tag index (if exists)
  /// 2. Adds/updates the entry in the entries map
  /// 3. Updates the tag index with the entry's tags
  ///
  /// ## Parameters
  ///
  /// - [db]: The cache file to modify
  /// - [entry]: The entry to upsert
  ///
  /// ## Tag Index Update
  ///
  /// For each tag in the entry:
  /// - Creates a new set in the index if the tag doesn't exist
  /// - Adds the entry's key to the tag's set
  void _upsertEntry(JsonCacheFile db, CacheEntry entry) {
    final previous = db.entries[entry.key];
    if (previous != null) _removeKeyFromTags(db, entry.key, previous.tags);

    db.entries[entry.key] = entry;

    for (final tag in entry.tags) {
      (db.tagIndex[tag] ??= <String>{}).add(entry.key);
    }
  }

  /// Flutter-friendly factory: resolves path via path_provider.
  ///
  /// This is the recommended way to create a backend in Flutter applications.
  /// It automatically resolves the appropriate directory based on the platform
  /// and creates the necessary directory structure.
  ///
  /// ## Parameters
  ///
  /// - [location]: Storage location (default: [CacheLocation.support])
  /// - [fileName]: Cache filename (default: 'typed_cache.json')
  /// - [subdir]: Optional subdirectory within the location
  /// - [enableRecovery]: Enable automatic recovery from backups (default: true)
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Simple usage
  /// final backend = await JsonFileCacheBackend.fromLocation(
  ///   location: CacheLocation.support,
  ///   fileName: 'app_cache.json',
  /// );
  ///
  /// // With subdirectory
  /// final backend = await JsonFileCacheBackend.fromLocation(
  ///   location: CacheLocation.support,
  ///   fileName: 'cache.json',
  ///   subdir: 'feature_name',
  ///   enableRecovery: true,
  /// );
  /// ```
  ///
  /// ## Returns
  ///
  /// A configured [JsonFileCacheBackend] instance ready to use.
  ///
  /// ## Throws
  ///
  /// May throw [FileSystemException] if unable to create the directory structure.
  static Future<JsonFileCacheBackend> fromLocation({
    CacheLocation location = CacheLocation.support,
    String fileName = 'typed_cache.json',
    String? subdir,
    bool enableRecovery = true,
  }) async {
    final f = await resolveCacheFile(location: location, fileName: fileName, subdir: subdir);
    return JsonFileCacheBackend(file: f, enableRecovery: enableRecovery);
  }
}
