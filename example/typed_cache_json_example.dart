// import 'package:typed_cache/typed_cache.dart';
// import 'package:typed_cache_json/src/flutter_path.dart';
// import 'package:typed_cache_json/typed_cache_json.dart';

// void main() async {
//   final backend = await JsonFileCacheBackend.fromLocation(
//     location: CacheLocation.support,
//     subdir: 'typed_cache',
//     fileName: 'cache.json',
//   );

//   final cache = CacheStore(backend: backend);
//   cache.put("dada", "value", codec: Teste());
// }

// class Teste implements CacheCodec<String> {
//   @override
//   String get typeId => "teste";

//   @override
//   String decode(Object? data) {
//     return data as String;
//   }

//   @override
//   Object encode(String value) {
//     return value;
//   }
// }
