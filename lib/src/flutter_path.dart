import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:typed_cache_json/src/json_utils.dart';

/// Resolves the cache file path based on the specified location and filename.
///
/// This function uses the `path_provider` package to determine the appropriate
/// directory for the cache file based on the [location] parameter, then
/// constructs the full file path including any subdirectory.
///
/// ## Path Resolution
///
/// The function:
/// 1. Ensures the filename has a `.json` extension (adds if missing)
/// 2. Resolves the base directory using `path_provider`
/// 3. Creates the subdirectory structure if it doesn't exist
/// 4. Returns a [File] object pointing to the cache file
///
/// ## Parameters
///
/// - [fileName]: The name of the cache file (default: 'typed_cache.json').
///   If no extension is provided, `.json` is automatically added.
/// - [location]: The storage location (see [CacheLocation])
/// - [subdir]: Optional subdirectory path within the base location.
///   Can be a simple name like 'my_cache' or a path like 'app/cache'.
///
/// ## Example
///
/// ```dart
/// // Simple cache file in application support
/// final file = await resolveCacheFile(
///   fileName: 'cache.json',
///   location: CacheLocation.support,
/// );
///
/// // Cache in a subdirectory
/// final file = await resolveCacheFile(
///   fileName: 'user_cache.json',
///   location: CacheLocation.support,
///   subdir: 'users/session',
/// );
/// ```
///
/// ## Returns
///
/// A [File] object pointing to the resolved cache file path.
/// The parent directory is created if it doesn't exist.
///
/// ## Throws
///
/// May throw [FileSystemException] if unable to create the directory structure.
Future<File> resolveCacheFile({
  String fileName = 'typed_cache.json',
  CacheLocation location = CacheLocation.support,
  String? subdir,
}) async {
  // Ensure the filename has a .json extension
  if (p.extension(fileName).isEmpty) {
    fileName = p.setExtension(fileName, '.json');
  }

  // Resolve the base directory based on location
  final Directory baseDir = switch (location) {
    CacheLocation.support => await getApplicationSupportDirectory(),
    CacheLocation.temporary => await getTemporaryDirectory(),
    CacheLocation.documents => await getApplicationDocumentsDirectory(),
  };

  // Construct the full directory path including subdirectory
  final dirPath = p.join(baseDir.path, subdir ?? '');
  final dir = Directory(dirPath);

  // Create the directory structure if it doesn't exist
  if (!await dir.exists()) await dir.create(recursive: true);

  // Return the full file path
  final filePath = p.join(dir.path, fileName);
  return File(filePath);
}
