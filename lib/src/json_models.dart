import 'package:typed_cache/typed_cache.dart';

final class JsonCacheFile<E> {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final Map<String, CacheEntry<E>> entries;
  final Map<String, Set<String>> tagIndex;
  JsonCacheFile({required this.schemaVersion, required this.entries, required this.tagIndex});

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'entries': entries.map((k, v) => MapEntry(k, entryToJson<E>(v))),
    'tagIndex': tagIndex.map((tag, keys) => MapEntry(tag, keys.toList())),
  };

  static JsonCacheFile<E> empty<E>() =>
      JsonCacheFile<E>(schemaVersion: currentSchemaVersion, entries: {}, tagIndex: {});

  static CacheEntry<E> entryFromJson<E>(Map<String, dynamic> json) => CacheEntry<E>(
    key: json['key'] as String,
    typeId: json['typeId'] as String,
    payload: json['payload'] as E,
    createdAtEpochMs: (json['createdAt'] as num).toInt(),
    expiresAtEpochMs: (json['expiresAt'] as num?)?.toInt(),
    tags: ((json['tags'] as List?) ?? const []).map((e) => e as String).toSet(),
  );

  static Map<String, dynamic> entryToJson<E>(CacheEntry<E> e) => <String, dynamic>{
    'key': e.key,
    'typeId': e.typeId,
    'payload': e.payload,
    'createdAt': e.createdAtEpochMs,
    'expiresAt': e.expiresAtEpochMs,
    'tags': e.tags.toList(growable: true),
  };

  static JsonCacheFile<E> fromJson<E>(Map<String, dynamic> json) {
    final schema = (json['schemaVersion'] as num?)?.toInt() ?? 1;

    final entriesRaw = (json['entries'] as Map?) ?? const {};
    final entries = <String, CacheEntry<E>>{};
    for (final MapEntry(:key, :value) in entriesRaw.entries) {
      entries[key as String] = JsonCacheFile.entryFromJson<E>(Map<String, dynamic>.from(value as Map));
    }

    final tagRaw = (json['tagIndex'] as Map?) ?? const {};
    final tagIndex = <String, Set<String>>{};
    for (final MapEntry(:key, :value) in tagRaw.entries) {
      tagIndex[key as String] = (value as List).map((e) => e as String).toSet();
    }

    return JsonCacheFile<E>(schemaVersion: schema, entries: entries, tagIndex: tagIndex);
  }
}
