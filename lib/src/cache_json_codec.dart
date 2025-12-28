import 'dart:convert';

import 'package:typed_cache/typed_cache.dart' show CacheCodec;

/// A simple codec for storing JSON-serializable data in the cache.
///
/// This codec encodes `Map<String, dynamic>` objects as JSON strings,
/// making it suitable for storing configuration, API responses, or any
/// other JSON-compatible data structures.
///
/// ## Type Parameters
///
/// - Input type: `Map<String, dynamic>` (your data in memory)
/// - Output type: `String` (JSON-encoded representation for storage)
///
/// ## Type ID
///
/// Uses the type ID `"json:v1"` to identify entries in the cache.
///
/// ## Example
///
/// ```dart
/// final cache = await create(
///   location: CacheLocation.support,
///   fileName: 'cache.json',
/// );
///
/// final codec = CacheJsonCodec();
///
/// // Store a Map
/// await cache.put('config', {
///   'theme': 'dark',
///   'language': 'pt-BR',
///   'version': 2,
/// }, codec: codec);
///
/// // Retrieve it
/// final config = await cache.get('config', codec: codec);
/// print(config?['theme']); // 'dark'
/// ```
///
/// ## Limitations
///
/// - Only supports JSON-serializable types (String, num, bool, List, Map, null)
/// - Does not preserve type information beyond what JSON supports
/// - For complex objects, consider creating a custom [CacheCodec]
class CacheJsonCodec implements CacheCodec<String, Map<String, dynamic>> {
  /// The type identifier for entries encoded with this codec.
  @override
  String get typeId => "json:v1";

  /// Decodes a JSON string back into a Map.
  ///
  /// ## Parameters
  ///
  /// - [data]: A JSON-encoded string
  ///
  /// ## Returns
  ///
  /// A `Map<String, dynamic>` representing the decoded JSON.
  ///
  /// ## Throws
  ///
  /// - [FormatException] if [data] is not valid JSON
  @override
  Map<String, dynamic> decode(String data) {
    return jsonDecode(data);
  }

  /// Encodes a Map into a JSON string.
  ///
  /// ## Parameters
  ///
  /// - [value]: A Map with JSON-serializable values
  ///
  /// ## Returns
  ///
  /// A JSON-encoded string representation of [value].
  ///
  /// ## Throws
  ///
  /// - [JsonUnsupportedObjectError] if [value] contains non-JSON-serializable objects
  @override
  String encode(Map<String, dynamic> value) {
    return jsonEncode(value);
  }
}
