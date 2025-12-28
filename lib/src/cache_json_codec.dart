import 'dart:convert';

import 'package:typed_cache/typed_cache.dart' show CacheCodec;

class CacheJsonCodec implements CacheCodec<String, Map<String, dynamic>> {
  @override
  String get typeId => "json:v1";
  @override
  Map<String, dynamic> decode(String data) {
    return jsonDecode(data);
  }

  @override
  String encode(Map<String, dynamic> value) {
    return jsonEncode(value);
  }
}
