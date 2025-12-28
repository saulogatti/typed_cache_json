import 'dart:io' show FileSystemException;

import 'package:typed_cache/typed_cache.dart' show TypedCache, createTypedCache, CacheLogger;
import 'package:typed_cache_json/src/cache_json_codec.dart';
import 'package:typed_cache_json/src/json_file_cache_backend.dart';

export 'package:typed_cache/typed_cache.dart' show TypedCache, CacheLogger;

/// Creates a fully configured [TypedCache] instance with JSON file backend.
///
/// This is the main entry point for creating a cache in Flutter applications.
/// It automatically resolves the storage path based on the [location] parameter
/// and configures the JSON backend with atomic writes and recovery capabilities.
///
/// ## Parameters
///
/// - [location]: Where to store the cache file (see [CacheLocation])
/// - [fileName]: Name of the JSON file (e.g., 'cache.json')
/// - [subdir]: Optional subdirectory within the location (e.g., 'my_app_cache')
/// - [enableRecovery]: If true, attempts to recover from .bak or .tmp files
///   when the main file is corrupted (default: true)
/// - [deleteCorruptedEntries]: If true, automatically removes entries that
///   cannot be decoded (default: true)
/// - [logger]: Optional logger for debugging and monitoring
///
/// ## Example
///
/// ```dart
/// // Basic usage
/// final cache = await create(
///   location: CacheLocation.support,
///   fileName: 'app_cache.json',
/// );
///
/// // With subdirectory and logging
/// final cache = await create(
///   location: CacheLocation.support,
///   fileName: 'cache.json',
///   subdir: 'my_feature',
///   logger: (msg) => print('[Cache] $msg'),
/// );
/// ```
///
/// ## Returns
///
/// A configured [TypedCache] instance ready to use.
///
/// ## Throws
///
/// May throw [FileSystemException] if unable to create the cache directory.
Future<TypedCache<String, Map<String, dynamic>>> create({
  required CacheLocation location,
  required String fileName,
  String? subdir,
  bool enableRecovery = true,
  bool deleteCorruptedEntries = true,
  CacheLogger? logger,
}) async {
  final backend = await JsonFileCacheBackend.fromLocation(
    location: location,
    fileName: fileName,
    subdir: subdir,
    enableRecovery: enableRecovery,
  );

  return createTypedCache<String, Map<String, dynamic>>(
    backend: backend,
    deleteCorruptedEntries: deleteCorruptedEntries,
    log: logger,
    defaultCodec: CacheJsonCodec(),
  );
}

/// Defines the storage location for the cache file in Flutter applications.
///
/// Each location maps to a specific directory provided by the `path_provider`
/// package, with different characteristics and use cases.
enum CacheLocation {
  /// Application support directory - recommended for cache files.
  ///
  /// This directory is for internal application files that should not be
  /// exposed to the user. Files here are included in backups (iOS) and
  /// persist across app updates.
  ///
  /// **Use this for**: Cache files, configuration, internal data.
  ///
  /// Maps to: `getApplicationSupportDirectory()`
  support,

  /// Temporary directory - for truly temporary cache data.
  ///
  /// The operating system may clear this directory at any time to free up
  /// disk space. Files here are not included in backups and may be deleted
  /// without warning.
  ///
  /// **Use this for**: Short-lived cache, downloaded temporary files.
  ///
  /// Maps to: `getTemporaryDirectory()`
  temporary,

  /// User documents directory - generally avoid for cache.
  ///
  /// This directory is intended for user-visible files and documents.
  /// Files here are included in backups and may be exposed through
  /// file browsers on some platforms.
  ///
  /// **Use this for**: User-created content, exported files.
  /// **Avoid for**: Internal cache or application data.
  ///
  /// Maps to: `getApplicationDocumentsDirectory()`
  documents,
}
