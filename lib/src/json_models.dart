import 'package:typed_cache/typed_cache.dart';

/// In-memory representation of the JSON cache file structure.
///
/// This class models the entire cache file, including all cache entries
/// and the tag index. It's generic over the payload type [E], which is
/// typically `Map<String, dynamic>` for JSON serialization.
///
/// ## JSON Structure
///
/// The file follows this schema:
/// ```json
/// {
///   "schemaVersion": 1,
///   "entries": {
///     "key1": { "key": "key1", "typeId": "...", "payload": {...}, ... }
///   },
///   "tagIndex": {
///     "tag1": ["key1", "key2"]
///   }
/// }
/// ```
///
/// ## Type Parameter
///
/// - [E]: The payload type for cache entries. For JSON storage, this is
///   typically `Map<String, dynamic>`.
final class JsonCacheFile<E> {
  /// The current schema version for the JSON file format.
  ///
  /// This version number is stored in the JSON file and can be used for
  /// future migrations if the file structure changes.
  static const int currentSchemaVersion = 1;

  /// The schema version of this cache file.
  ///
  /// Used for compatibility checks and potential future migrations.
  final int schemaVersion;

  /// Map of cache entries keyed by their cache key.
  ///
  /// Each entry contains the key, type ID, payload, timestamps, and tags.
  final Map<String, CacheEntry<E>> entries;

  /// Reverse index mapping tags to the set of keys that have that tag.
  ///
  /// This allows efficient tag-based operations like [keysByTag] and
  /// [deleteTag] without scanning all entries.
  ///
  /// Example: `{'session': {'key1', 'key2'}, 'auth': {'key1'}}`
  final Map<String, Set<String>> tagIndex;

  /// Creates a new cache file with the given data.
  ///
  /// Typically not called directly - use [empty] or [fromJson] instead.
  JsonCacheFile({required this.schemaVersion, required this.entries, required this.tagIndex});

  /// Serializes this cache file to a JSON-compatible map.
  ///
  /// The returned map can be encoded with `jsonEncode()` to write to disk.
  ///
  /// ## Returns
  ///
  /// A map with keys:
  /// - `schemaVersion`: The file format version
  /// - `entries`: Map of serialized cache entries
  /// - `tagIndex`: Map of tags to arrays of keys
  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'entries': entries.map((k, v) => MapEntry(k, entryToJson<E>(v))),
        'tagIndex': tagIndex.map((tag, keys) => MapEntry(tag, keys.toList())),
      };

  /// Creates an empty cache file with no entries.
  ///
  /// Uses the current schema version and initializes empty entry and tag maps.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final emptyCache = JsonCacheFile<Map<String, dynamic>>.empty();
  /// ```
  static JsonCacheFile<E> empty<E>() =>
      JsonCacheFile<E>(schemaVersion: currentSchemaVersion, entries: {}, tagIndex: {});

  /// Deserializes a cache entry from JSON.
  ///
  /// Converts a JSON map (as stored in the file) into a [CacheEntry] object.
  ///
  /// ## Parameters
  ///
  /// - [json]: A map containing the entry data with keys: key, typeId, payload,
  ///   createdAt, expiresAt, tags
  ///
  /// ## Returns
  ///
  /// A [CacheEntry] with the deserialized data.
  static CacheEntry<E> entryFromJson<E>(Map<String, dynamic> json) => CacheEntry<E>(
        key: json['key'] as String,
        typeId: json['typeId'] as String,
        payload: json['payload'] as E,
        createdAtEpochMs: (json['createdAt'] as num).toInt(),
        expiresAtEpochMs: (json['expiresAt'] as num?)?.toInt(),
        tags: ((json['tags'] as List?) ?? const []).map((e) => e as String).toSet(),
      );

  /// Serializes a cache entry to JSON.
  ///
  /// Converts a [CacheEntry] object into a JSON-compatible map for storage.
  ///
  /// ## Parameters
  ///
  /// - [e]: The cache entry to serialize
  ///
  /// ## Returns
  ///
  /// A map containing all entry fields in JSON-compatible format.
  static Map<String, dynamic> entryToJson<E>(CacheEntry<E> e) => <String, dynamic>{
        'key': e.key,
        'typeId': e.typeId,
        'payload': e.payload,
        'createdAt': e.createdAtEpochMs,
        'expiresAt': e.expiresAtEpochMs,
        'tags': e.tags.toList(growable: true),
      };

  /// Deserializes a complete cache file from JSON.
  ///
  /// Parses the JSON structure and reconstructs the cache file with all
  /// entries and the tag index.
  ///
  /// ## Parameters
  ///
  /// - [json]: A map representing the entire cache file structure
  ///
  /// ## Returns
  ///
  /// A [JsonCacheFile] instance with all deserialized data.
  ///
  /// ## Error Handling
  ///
  /// Uses safe defaults for missing fields:
  /// - Missing schema version defaults to 1
  /// - Missing entries/tagIndex default to empty maps
  ///
  /// ## Example
  ///
  /// ```dart
  /// final text = await file.readAsString();
  /// final json = jsonDecode(text);
  /// final cacheFile = JsonCacheFile.fromJson<Map<String, dynamic>>(json);
  /// ```
  static JsonCacheFile<E> fromJson<E>(Map<String, dynamic> json) {
    final schema = (json['schemaVersion'] as num?)?.toInt() ?? 1;

    // Deserialize entries
    final entriesRaw = (json['entries'] as Map?) ?? const {};
    final entries = <String, CacheEntry<E>>{};
    for (final MapEntry(:key, :value) in entriesRaw.entries) {
      entries[key as String] = JsonCacheFile.entryFromJson<E>(Map<String, dynamic>.from(value as Map));
    }

    // Deserialize tag index
    final tagRaw = (json['tagIndex'] as Map?) ?? const {};
    final tagIndex = <String, Set<String>>{};
    for (final MapEntry(:key, :value) in tagRaw.entries) {
      tagIndex[key as String] = (value as List).map((e) => e as String).toSet();
    }

    return JsonCacheFile<E>(schemaVersion: schema, entries: entries, tagIndex: tagIndex);
  }
}
