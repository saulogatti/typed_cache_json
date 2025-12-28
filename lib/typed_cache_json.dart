/// A JSON-based backend implementation for the `typed_cache` package.
///
/// This library provides persistent, typed caching with atomic file operations,
/// auto-recovery, and tag-based indexing. It's designed for Flutter and Dart
/// applications that need lightweight, reliable data persistence.
///
/// ## Features
///
/// - **Type-safe caching**: Store and retrieve objects with type safety
/// - **JSON persistence**: All data saved in a single local JSON file
/// - **Atomic writes**: Uses temporary and backup files to prevent corruption
/// - **Auto-recovery**: Attempts to recover from backup files if main file is corrupted
/// - **TTL support**: Set expiration time for cache entries
/// - **Tag-based indexing**: Organize and batch-remove cache entries using tags
/// - **Flutter integration**: Easy path resolution for different storage locations
/// - **Thread-safe**: All operations protected by async mutex
///
/// ## Quick Start
///
/// ```dart
/// import 'package:typed_cache_json/typed_cache_json.dart';
///
/// // Create a cache
/// final cache = await create(
///   location: CacheLocation.support,
///   fileName: 'my_cache.json',
/// );
///
/// // Use with a codec
/// final codec = CacheJsonCodec();
/// await cache.put('key', {'data': 'value'}, codec: codec);
/// final data = await cache.get('key', codec: codec);
/// ```
///
/// For more examples and advanced usage, see the README.
library;

export 'src/cache_json_codec.dart';
export 'src/json_utils.dart';
