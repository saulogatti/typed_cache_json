import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:typed_cache_json/src/json_utils.dart';

/// Resolve o arquivo de cache baseado na localização desejada.
Future<File> resolveCacheFile({
  String fileName = 'typed_cache.json',
  CacheLocation location = CacheLocation.support,
  String? subdir, // ex: 'typed_cache'
}) async {
  if (p.extension(fileName).isEmpty) {
    fileName = p.setExtension(fileName, '.json');
  }
  final Directory baseDir = switch (location) {
    CacheLocation.support => await getApplicationSupportDirectory(),
    CacheLocation.temporary => await getTemporaryDirectory(),
    CacheLocation.documents => await getApplicationDocumentsDirectory(),
  };
  final dirPath = p.join(baseDir.path, subdir ?? '');
  final dir = Directory(dirPath);
  if (!await dir.exists()) await dir.create(recursive: true);
  final filePath = p.join(dir.path, fileName);
  return File(filePath);
}
