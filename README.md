# typed_cache_json

Um backend de cache baseado em JSON para o pacote `typed_cache`. Oferece uma solução simples, tipada e persistente para armazenamento de dados em um único arquivo JSON, ideal para aplicações Flutter e Dart que precisam de persistência leve.

## Características

- **Cache Tipado:** Armazene e recupere objetos com segurança de tipos usando `CacheCodec`.
- **Persistência JSON:** Todos os dados são salvos em um único arquivo JSON local.
- **Escritas Atômicas:** Utiliza arquivos temporários e de backup para evitar corrupção de dados durante a gravação.
- **Suporte a Expiração (TTL):** Defina tempo de vida para suas entradas de cache.
- **Indexação por Tags:** Organize e remova entradas de cache em massa usando tags.
- **Integração com Flutter:** Resolução fácil de caminhos (Application Support, Documents, Temporary, etc.) via `path_provider`.
- **Recuperação Automática:** Tenta recuperar dados de backups caso o arquivo principal seja corrompido.

## Começando

Adicione a dependência ao seu `pubspec.yaml`:

```yaml
dependencies:
  typed_cache_json:
    git:
      url: https://github.com/saulogatti/typed_cache_json.git
```

## Uso

### Configuração Básica (Flutter)

A forma mais fácil de começar no Flutter é usando o factory `fromLocation`:

```dart
import 'package:typed_cache_json/typed_cache_json.dart';

void main() async {
  // Inicializa o backend apontando para a pasta de suporte da aplicação
  final backend = await JsonFileCacheBackend.fromLocation(
    location: CacheLocation.support,
    subdir: 'my_app_cache',
    fileName: 'cache.json',
  );

  // Cria o store
  final cache = JsonStore(backend: backend);
}
```

### Armazenando e Recuperando Dados

Para usar o cache, você precisa definir um `CacheCodec` para o seu tipo de dado. O pacote fornece `JsonCacheCodec` para facilitar o trabalho com Maps:

```dart
class User {
  final String name;
  final int age;
  User(this.name, this.age);
}

class UserCodec extends JsonCacheCodec<User> {
  @override
  String get typeId => 'user';

  @override
  User decode(Map<String, Object?> data) {
    return User(data['name'] as String, data['age'] as int);
  }

  @override
  Map<String, Object?> encode(User value) {
    return {'name': value.name, 'age': value.age};
  }
}

// ...

final user = User('Saulo', 30);
final codec = UserCodec();

// Salvar
await cache.put('user_1', user, codec: codec);

// Recuperar
final cachedUser = await cache.get('user_1', codec: codec);
```

### Usando Tags e TTL

```dart
// Salvar com expiração de 1 hora e tags
await cache.put(
  'session_data', 
  data, 
  codec: myCodec,
  ttl: Duration(hours: 1),
  tags: {'session', 'auth'},
);

// Invalidar tudo que tem a tag 'session'
await cache.invalidateByTag('session');
```

### Limpeza de Cache Expirado

O cache não remove entradas expiradas automaticamente do disco (exceto quando você tenta ler uma chave expirada). Para limpar o arquivo:

```dart
// Remove todas as entradas expiradas do arquivo JSON
final count = await cache.purgeExpired();
print('$count entradas removidas');
```

## Estrutura do Arquivo

O backend mantém um arquivo JSON com a seguinte estrutura:

```json
{
  "schemaVersion": 1,
  "entries": {
    "key1": {
      "key": "key1",
      "typeId": "user",
      "payload": { "name": "Saulo", "age": 30 },
      "createdAt": 1700000000000,
      "expiresAt": 1700003600000,
      "tags": ["session"]
    }
  },
  "tagIndex": {
    "session": ["key1"]
  }
}
```

## Informações Adicionais

Este pacote é um complemento ao `typed_cache`. Para mais detalhes sobre como criar codecs complexos ou políticas de TTL personalizadas, consulte a documentação do `typed_cache`.
