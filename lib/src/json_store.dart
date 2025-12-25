import 'package:typed_cache/typed_cache.dart';
import 'package:typed_cache_json/src/json_file_cache_backend.dart';

typedef CacheLogger =
    void Function(String message, Object? error, StackTrace? st);

final class JsonStore implements TypedCache {
  final JsonFileCacheBackend _backend;
  final Clock _clock;
  final TtlPolicy _ttlPolicy;
  final CacheLogger? _log;

  /// If true: on decode/type mismatch, delete entry and return null.
  /// If false: throw.
  final bool deleteCorruptedEntries;

  JsonStore({
    required JsonFileCacheBackend backend,
    Clock clock = const SystemClock(),
    TtlPolicy ttlPolicy = const DefaultTtlPolicy(),
    CacheLogger? logger,
    this.deleteCorruptedEntries = true,
  }) : _backend = backend,
       _clock = clock,
       _ttlPolicy = ttlPolicy,
       _log = logger;

  @override
  Future<void> clear() => _backend.clear();

  @override
  Future<bool> contains(String key) async {
    final entry = await _backend.read(key);
    if (entry == null) return false;

    final now = _clock.nowEpochMs();
    if (entry.isExpired(now)) return false;

    return true;
  }

  @override
  Future<D?> get<E, D extends Object>(
    String key, {
    required CacheCodec<E, D> codec,
    bool allowExpired = false,
  }) async {
    final now = _clock.nowEpochMs();
    CacheEntry? entry;

    try {
      entry = await _backend.read(key);
    } catch (e, st) {
      _log?.call('Backend read failed for key="$key"', e, st);
      throw CacheBackendException('Backend read failed for key="$key": $e');
    }

    if (entry == null) return null;

    if (!allowExpired && entry.isExpired(now)) {
      // Lazy expiration cleanup.
      try {
        await _backend.delete(key);
      } catch (e, st) {
        _log?.call('Failed to delete expired key="$key"', e, st);
      }
      return null;
    }

    if (entry.typeId != codec.typeId) {
      final msg =
          'Type mismatch for key="$key": stored="${entry.typeId}" requested="${codec.typeId}"';
      if (deleteCorruptedEntries) {
        _log?.call(msg, null, null);
        try {
          await _backend.delete(key);
        } catch (e, st) {
          _log?.call('Failed to delete mismatched key="$key"', e, st);
        }
        return null;
      }
      throw CacheTypeMismatchException(msg);
    }

    try {
      return codec.decode(entry.payload);
    } catch (e, st) {
      final msg = 'Decode failed for key="$key" typeId="${codec.typeId}"';
      if (deleteCorruptedEntries) {
        _log?.call(msg, e, st);
        try {
          await _backend.delete(key);
        } catch (e2, st2) {
          _log?.call('Failed to delete corrupted key="$key"', e2, st2);
        }
        return null;
      }
      throw CacheDecodeException(msg, cause: e, stackTrace: st);
    }
  }

  @override
  Future<D> getOrFetch<E, D extends Object>(
    String key, {
    required CacheCodec<E, D> codec,
    required Future<D> Function() fetch,
    Duration? ttl,
    Set<String> tags = const {},
    bool allowExpiredWhileRevalidating = false,
  }) async {
    final cached = await get<E, D>(
      key,
      codec: codec,
      allowExpired: allowExpiredWhileRevalidating,
    );

    if (cached != null && !allowExpiredWhileRevalidating) return cached;

    if (cached != null && allowExpiredWhileRevalidating) {
      // Fire-and-forget refresh, but we can't do real background tasks here.
      // We return cached and refresh in the same async chain (best effort).
      try {
        final fresh = await fetch();
        await put<E, D>(key, fresh, codec: codec, ttl: ttl, tags: tags);
      } catch (e, st) {
        _log?.call('SWR refresh failed for key="$key"', e, st);
      }
      return cached;
    }

    final fresh = await fetch();
    await put<E, D>(key, fresh, codec: codec, ttl: ttl, tags: tags);
    return fresh;
  }

  @override
  Future<void> invalidate(String key) => _backend.delete(key);

  @override
  Future<void> invalidateByTag(String tag) async {
    final keys = await _backend.keysByTag(tag);
    // Best effort delete all.
    for (final k in keys) {
      try {
        await _backend.delete(k);
      } catch (e, st) {
        _log?.call('Failed to delete key="$k" from tag="$tag"', e, st);
      }
    }
    // Also remove tag mapping if backend keeps a separate index.
    try {
      await _backend.deleteTag(tag);
    } catch (_) {
      // Optional: backend may not support.
    }
  }

  @override
  Future<int> purgeExpired() async {
    final now = _clock.nowEpochMs();
    try {
      return await _backend.purgeExpired(now);
    } catch (e, st) {
      _log?.call('Backend purgeExpired failed', e, st);
      return 0;
    }
  }

  @override
  Future<void> put<E, D extends Object>(
    String key,
    D value, {
    required CacheCodec<E, D> codec,
    Duration? ttl,
    Set<String> tags = const {},
  }) async {
    final now = _clock.nowEpochMs();
    final expiresAt = _ttlPolicy.computeExpiresAtEpochMs(
      ttl: ttl,
      clock: _clock,
    );

    final entry = CacheEntry(
      key: key,
      typeId: codec.typeId,
      payload: codec.encode(value),
      createdAtEpochMs: now,
      expiresAtEpochMs: expiresAt,
      tags: tags,
    );

    try {
      await _backend.write(entry);
    } catch (e, st) {
      throw CacheBackendException(
        'Backend write failed for key="$key": $e'
        '\n${st.toString()}',
      );
    }
  }
}
