import 'package:typed_cache/typed_cache.dart';

final class JsonCacheFile {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final Map<String, CacheEntry> entries;
  final Map<String, Set<String>> tagIndex;
  JsonCacheFile({
    required this.schemaVersion,
    required this.entries,
    required this.tagIndex,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'entries': entries.map((k, v) => MapEntry(k, entryToJson(v))),
    'tagIndex': tagIndex.map((tag, keys) => MapEntry(tag, keys.toList())),
  };

  static JsonCacheFile empty() => JsonCacheFile(
    schemaVersion: currentSchemaVersion,
    entries: {},
    tagIndex: {},
  );

  static CacheEntry entryFromJson(Map<String, Object?> json) => CacheEntry(
    key: json['key'] as String,
    typeId: json['typeId'] as String,
    payload: json['payload'] as Object,
    createdAtEpochMs: (json['createdAt'] as num).toInt(),
    expiresAtEpochMs: (json['expiresAt'] as num?)?.toInt(),
    tags: ((json['tags'] as List?) ?? const []).map((e) => e as String).toSet(),
  );

  static Map<String, Object?> entryToJson(CacheEntry e) => <String, Object?>{
    'key': e.key,
    'typeId': e.typeId,
    'payload': e.payload,
    'createdAt': e.createdAtEpochMs,
    'expiresAt': e.expiresAtEpochMs,
    'tags': e.tags.toList(growable: true),
  };

  static JsonCacheFile fromJson(Map<String, Object?> json) {
    final schema = (json['schemaVersion'] as num?)?.toInt() ?? 1;

    final entriesRaw = (json['entries'] as Map?) ?? const {};
    final entries = <String, CacheEntry>{};
    for (final MapEntry(:key, :value) in entriesRaw.entries) {
      entries[key as String] = JsonCacheFile.entryFromJson(
        Map<String, Object?>.from(value as Map),
      );
    }

    final tagRaw = (json['tagIndex'] as Map?) ?? const {};
    final tagIndex = <String, Set<String>>{};
    for (final MapEntry(:key, :value) in tagRaw.entries) {
      tagIndex[key as String] = (value as List).map((e) => e as String).toSet();
    }

    return JsonCacheFile(
      schemaVersion: schema,
      entries: entries,
      tagIndex: tagIndex,
    );
  }
}
