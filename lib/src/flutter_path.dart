import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:typed_cache_json/src/json_utils.dart';

Future<File> resolveCacheFile({
  String fileName = 'typed_cache.json',
  CacheLocation location = CacheLocation.support,
  String? subdir, // ex: 'typed_cache'
}) async {
  final Directory baseDir = switch (location) {
    CacheLocation.support => await getApplicationSupportDirectory(),
    CacheLocation.temporary => await getTemporaryDirectory(),
    CacheLocation.documents => await getApplicationDocumentsDirectory(),
  };

  final dir = subdir == null ? baseDir : Directory('${baseDir.path}/$subdir');
  if (!await dir.exists()) await dir.create(recursive: true);

  return File('${dir.path}/$fileName');
}
