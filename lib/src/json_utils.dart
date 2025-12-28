import 'package:flutter/foundation.dart';
import 'package:typed_cache/typed_cache.dart' show TypedCache, createTypedCache;
import 'package:typed_cache_json/src/json_file_cache_backend.dart';

export 'package:typed_cache/typed_cache.dart' show TypedCache;

enum CacheLocation {
  /// Arquivos internos não expostos ao usuário (recomendado).
  support,

  /// Cache temporário; o SO pode limpar quando quiser.
  temporary,

  /// Documentos do usuário (evite pra cache).
  documents,
}

/// Usando mixin para evitar instanciação direta
mixin JsonUtils {
  @nonVirtual
  Future<TypedCache> create({
    required CacheLocation location,
    required String fileName,
    String? subdir, // ex: 'typed_cache'
    bool enableRecovery = true,
    bool deleteCorruptedEntries = true,
  }) async {
    final backend = await JsonFileCacheBackend.fromLocation(
      location: location,
      fileName: fileName,
      subdir: subdir,
      enableRecovery: enableRecovery,
    );
    return createTypedCache(backend: backend, deleteCorruptedEntries: deleteCorruptedEntries);
  }
}
