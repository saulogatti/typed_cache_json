import 'package:typed_cache/typed_cache.dart';

abstract class JsonCacheCodec<T extends Object> implements CacheCodec<Map<String, dynamic>, T> {
  @override
  T decode(Map<String, dynamic> data);

  @override
  Map<String, dynamic> encode(T value);
}
