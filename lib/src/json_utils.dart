import 'package:typed_cache/typed_cache.dart' show TypedCache, createTypedCache, CacheLogger;
import 'package:typed_cache_json/src/json_file_cache_backend.dart';

export 'package:typed_cache/typed_cache.dart' show TypedCache, CacheLogger;

/// Usando mixin para evitar instanciação direta

Future<TypedCache> create({
  required CacheLocation location,
  required String fileName,
  String? subdir, // ex: 'typed_cache'
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
  return createTypedCache(backend: backend, deleteCorruptedEntries: deleteCorruptedEntries, log: logger);
}

enum CacheLocation {
  /// Arquivos internos não expostos ao usuário (recomendado).
  support,

  /// Cache temporário; o SO pode limpar quando quiser.
  temporary,

  /// Documentos do usuário (evite pra cache).
  documents,
}
