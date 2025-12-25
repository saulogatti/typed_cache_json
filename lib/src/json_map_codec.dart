import 'package:typed_cache/typed_cache.dart';

abstract class JsonCacheCodec<T extends Object>
    implements CacheCodec<Map<String, Object?>, T> {
  @override
  T decode(Map<String, Object?> data);

  @override
  Map<String, Object?> encode(T value);
}
