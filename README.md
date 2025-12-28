# typed_cache_json

[![Version](https://img.shields.io/badge/version-0.2.1-blue.svg)](https://github.com/saulogatti/typed_cache_json)

Um backend de cache baseado em JSON para o pacote `typed_cache`. Oferece uma solução simples, tipada e persistente para armazenamento de dados em um único arquivo JSON, ideal para aplicações Flutter e Dart que precisam de persistência leve.

## Características

- **Cache Tipado:** Armazene e recupere objetos com segurança de tipos usando `CacheCodec`.
- **Persistência JSON:** Todos os dados são salvos em um único arquivo JSON local.
- **Escritas Atômicas:** Utiliza arquivos temporários (`.tmp`) e de backup (`.bak`) para evitar corrupção de dados durante a gravação.
- **Recuperação Automática:** Tenta recuperar dados de backups caso o arquivo principal seja corrompido.
- **Suporte a Expiração (TTL):** Defina tempo de vida para suas entradas de cache.
- **Indexação por Tags:** Organize e remova entradas de cache em massa usando tags.
- **Integração com Flutter:** Resolução fácil de caminhos (`ApplicationSupport`, `Documents`, `Temporary`) via `path_provider`.
- **Thread-Safe:** Operações protegidas por mutex assíncrono, garantindo segurança em ambientes concorrentes.

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

A forma mais fácil de começar no Flutter é usando a função `create`:

```dart
import 'package:typed_cache_json/typed_cache_json.dart';

void main() async {
  // Inicializa o cache apontando para a pasta de suporte da aplicação
  final cache = await create(
    location: CacheLocation.support,
    subdir: 'my_app_cache',
    fileName: 'cache.json',
  );
  
  // Agora você pode usar o cache!
}
```

#### Localizações Disponíveis

O enum `CacheLocation` define onde o arquivo de cache será armazenado:

- **`CacheLocation.support`** (Recomendado): Arquivos internos não expostos ao usuário
- **`CacheLocation.temporary`**: Cache temporário; o SO pode limpar quando necessário
- **`CacheLocation.documents`**: Documentos do usuário (evite para cache)

### Configuração Avançada

Se você precisar de mais controle, pode criar o backend diretamente:

```dart
import 'package:typed_cache_json/typed_cache_json.dart';
import 'package:typed_cache_json/src/json_file_cache_backend.dart';

void main() async {
  // Cria o backend com configurações personalizadas
  final backend = await JsonFileCacheBackend.fromLocation(
    location: CacheLocation.support,
    subdir: 'my_app_cache',
    fileName: 'cache.json',
    enableRecovery: true, // Habilita recuperação automática (padrão: true)
  );

  // Cria o cache com o backend
  final cache = createTypedCache(
    backend: backend,
    deleteCorruptedEntries: true, // Remove entradas corrompidas automaticamente
  );
}
```

### Armazenando e Recuperando Dados

Para usar o cache, você precisa definir um `CacheCodec` para o seu tipo de dado:

```dart
import 'package:typed_cache/typed_cache.dart';

class User {
  final String name;
  final int age;
  User(this.name, this.age);
}

class UserCodec extends CacheCodec<User, Map<String, dynamic>> {
  @override
  String get typeId => 'user';

  @override
  User decode(Map<String, dynamic> data) {
    return User(data['name'] as String, data['age'] as int);
  }

  @override
  Map<String, dynamic> encode(User value) {
    return {'name': value.name, 'age': value.age};
  }
}

// Usando o cache
void main() async {
  final cache = await create(
    location: CacheLocation.support,
    fileName: 'cache.json',
  );
  
  final user = User('Saulo', 30);
  final codec = UserCodec();

  // Salvar
  await cache.put('user_1', user, codec: codec);

  // Recuperar
  final cachedUser = await cache.get('user_1', codec: codec);
  print('Nome: ${cachedUser?.name}, Idade: ${cachedUser?.age}');
}
```

### Usando o Codec JSON Pré-definido

Para dados simples em formato Map, você pode usar o `CacheJsonCodec` incluído:

```dart
import 'package:typed_cache_json/typed_cache_json.dart';

void main() async {
  final cache = await create(
    location: CacheLocation.support,
    fileName: 'cache.json',
  );
  
  final codec = CacheJsonCodec();
  
  // Salvar um Map diretamente
  await cache.put('config', {'theme': 'dark', 'version': 2}, codec: codec);
  
  // Recuperar
  final config = await cache.get('config', codec: codec);
  print('Theme: ${config?['theme']}');
}
```

### Usando Tags e TTL

```dart
// Salvar com expiração de 1 hora e tags
await cache.put(
  'session_data', 
  sessionData, 
  codec: myCodec,
  ttl: Duration(hours: 1),
  tags: {'session', 'auth'},
);

// Invalidar tudo que tem a tag 'session'
await cache.invalidateByTag('session');

// Buscar todas as chaves com uma tag específica
final sessionKeys = await cache.keysByTag('session');
print('Chaves da sessão: $sessionKeys');
```

### Limpeza de Cache Expirado

O cache não remove entradas expiradas automaticamente do disco (exceto quando você tenta ler uma chave expirada). Para limpar o arquivo:

```dart
// Remove todas as entradas expiradas do arquivo JSON
final count = await cache.purgeExpired();
print('$count entradas removidas');
```

### Limpeza Completa

Para remover todos os dados do cache:

```dart
// Limpa todo o cache
await cache.clear();
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

### Arquivos de Segurança

Durante operações de escrita, o backend cria arquivos auxiliares:

- **`cache.json.tmp`**: Arquivo temporário usado durante a escrita
- **`cache.json.bak`**: Backup do arquivo anterior, usado para recuperação em caso de corrupção

Esses arquivos são gerenciados automaticamente e garantem a integridade dos dados.

## Recuperação de Dados

O pacote inclui um sistema robusto de recuperação de dados:

1. Se o arquivo principal estiver corrompido, tenta carregar do `.bak`
2. Se o `.bak` também estiver corrompido, tenta o `.tmp`
3. Se nenhum funcionar, inicializa um cache vazio

Você pode desabilitar a recuperação automática ao criar o backend:

```dart
final backend = await JsonFileCacheBackend.fromLocation(
  location: CacheLocation.support,
  fileName: 'cache.json',
  enableRecovery: false, // Desabilita recuperação
);
```

## Logging

Para debug e monitoramento, você pode ativar logs ao criar o cache:

```dart
final cache = await create(
  location: CacheLocation.support,
  fileName: 'cache.json',
  logger: (message) => print('[Cache] $message'),
);
```

## Informações Adicionais

### Compatibilidade

- **Dart SDK**: ^3.10.4
- **Flutter**: Compatível
- **Plataformas**: iOS, Android, macOS, Windows, Linux

### Links Úteis

- [typed_cache](https://github.com/saulogatti/typed_cache) - Pacote base para cache tipado
- [Repositório](https://github.com/saulogatti/typed_cache_json)

### Recursos Avançados

Para mais detalhes sobre:
- Criação de codecs complexos
- Políticas de TTL personalizadas
- Estratégias de invalidação
- Otimizações de performance

Consulte a [documentação do typed_cache](https://github.com/saulogatti/typed_cache).

## Contribuindo

Contribuições são bem-vindas! Sinta-se à vontade para abrir issues ou pull requests.

## Licença

Este projeto é de código aberto. Verifique o arquivo LICENSE para mais detalhes.
