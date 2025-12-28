# typed_cache_json

[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](https://github.com/saulogatti/typed_cache_json)

Um backend de cache baseado em JSON para o pacote `typed_cache`. Oferece uma solução simples, tipada e persistente para armazenamento de dados em um único arquivo JSON, ideal para aplicações Flutter e Dart que precisam de persistência leve.

> **📚 Documentação Completa:** Todo o código está totalmente documentado com comentários DartDoc. Use o autocompletar da sua IDE ou gere a documentação com `dart doc` para explorar a API completa.

## Características

- **Cache Tipado:** Armazene e recupere objetos com segurança de tipos usando `CacheCodec`.
- **Persistência JSON:** Todos os dados são salvos em um único arquivo JSON local.
- **Escritas Atômicas:** Utiliza arquivos temporários (`.tmp`) e de backup (`.bak`) para evitar corrupção de dados durante a gravação.
- **Recuperação Automática:** Tenta recuperar dados de backups caso o arquivo principal seja corrompido.
- **Suporte a Expiração (TTL):** Defina tempo de vida para suas entradas de cache.
- **Indexação por Tags:** Organize e remova entradas de cache em massa usando tags.
- **Integração com Flutter:** Resolução fácil de caminhos (`ApplicationSupport`, `Documents`, `Temporary`) via `path_provider`.
- **Thread-Safe:** Operações protegidas por mutex assíncrono, garantindo segurança em ambientes concorrentes.
- **Documentação Completa:** API totalmente documentada com exemplos e explicações detalhadas.

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

## Arquitetura e Funcionamento Interno

### Componentes Principais

O pacote é organizado em componentes especializados:

#### 1. **JsonFileCacheBackend**
Backend principal que implementa `CacheBackend` do `typed_cache`. Responsável por:
- Operações de leitura/escrita atômicas
- Gerenciamento do ciclo de vida das entradas
- Manutenção do índice de tags
- Recuperação automática de falhas

#### 2. **AsyncMutex**
Mutex assíncrono que serializa operações concorrentes. Garante que:
- Operações de I/O não se sobreponham
- Estado interno permaneça consistente
- Erros em uma operação não bloqueiem as seguintes

#### 3. **JsonCacheFile**
Modelo de dados que representa a estrutura do arquivo JSON em memória:
- Armazena todas as entradas do cache
- Mantém índice reverso de tags para buscas eficientes
- Serializa/deserializa o arquivo JSON

#### 4. **CacheJsonCodec**
Codec pré-definido para dados JSON simples (`Map<String, dynamic>`):
- Facilita armazenamento de configurações e dados estruturados
- Sem necessidade de criar codecs personalizados para dados simples

### Fluxo de Operações

#### Escrita (write)
```
TypedCache.put() 
  → JsonFileCacheBackend.write()
  → _mutex.synchronized()
    → _load() (carrega arquivo)
    → _upsertEntry() (atualiza entrada e índice de tags)
    → _save()
      → _atomicWrite() (escreve .tmp → renomeia → backup .bak)
```

#### Leitura (read)
```
TypedCache.get()
  → JsonFileCacheBackend.read()
  → _mutex.synchronized()
    → _load() (carrega e faz cache em memória durante a operação)
    → retorna entrada ou null
```

#### Recuperação de Falhas
```
_load() falha
  → _recoverOrEmpty() (se enableRecovery = true)
    → tenta .bak
    → tenta .tmp
    → retorna vazio se todos falharem
```

### Garantias de Thread-Safety

Todas as operações públicas são protegidas pelo `AsyncMutex`, garantindo:
- **Serialização:** Operações executam uma de cada vez, na ordem de submissão
- **Consistência:** Estado do arquivo e índices sempre sincronizados
- **Isolamento:** Falhas em uma operação não afetam outras

### Garantias de Durabilidade

O protocolo de escrita atômica garante:
- **Atomicidade:** Escrita completa ou nenhuma escrita (sem corrupção parcial)
- **Backup Automático:** Versão anterior sempre preservada em `.bak`
- **Recuperação:** Sistema tenta múltiplos caminhos antes de desistir

## Informações Adicionais

### Compatibilidade

- **Dart SDK**: ^3.10.4
- **Flutter**: Compatível
- **Plataformas**: iOS, Android, macOS, Windows, Linux

### Documentação da API

Todo o código deste pacote está completamente documentado com comentários DartDoc. A documentação inclui:

- **Descrições Detalhadas:** Cada classe, método e propriedade possui uma descrição clara
- **Exemplos de Uso:** Exemplos práticos para as principais funcionalidades
- **Parâmetros e Retornos:** Documentação completa de todos os parâmetros e valores de retorno
- **Exceções:** Informações sobre possíveis erros e como tratá-los
- **Notas de Implementação:** Detalhes sobre o comportamento interno e garantias de thread-safety

#### Como Acessar a Documentação

1. **Via IDE:** Use o autocompletar (Ctrl+Space / Cmd+Space) e hover sobre qualquer símbolo para ver a documentação inline
2. **Gerar HTML:** Execute `dart doc` no diretório do projeto para gerar documentação HTML navegável
3. **Leia o Código:** Os comentários DartDoc estão visíveis diretamente nos arquivos fonte

#### Principais Classes Documentadas

- **`JsonFileCacheBackend`:** Backend principal com operações atômicas e recuperação automática
- **`AsyncMutex`:** Implementação de mutex assíncrono para serialização de operações
- **`CacheJsonCodec`:** Codec pré-definido para dados JSON simples
- **`JsonCacheFile`:** Modelo interno do arquivo de cache
- **`CacheLocation`:** Enum para escolha de localização do arquivo

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

## Melhores Práticas

### Escolha da Localização

- **Use `CacheLocation.support`** para a maioria dos casos - é o local recomendado para cache
- **Use `CacheLocation.temporary`** apenas para cache verdadeiramente descartável que pode ser limpo pelo SO
- **Evite `CacheLocation.documents`** para cache - é para arquivos visíveis ao usuário

### Gerenciamento de Tags

```dart
// Organize entradas relacionadas com tags
await cache.put('user_123', userData, codec: codec, tags: {'user', 'session'});
await cache.put('config_123', configData, codec: codec, tags: {'config', 'session'});

// Limpe tudo relacionado à sessão de uma vez
await cache.invalidateByTag('session');
```

### Limpeza Periódica

```dart
// Execute periodicamente para manter o arquivo otimizado
Future<void> performCacheMaintenance() async {
  final removed = await cache.purgeExpired();
  print('Removidas $removed entradas expiradas');
}

// Exemplo: executar ao iniciar o app
void main() async {
  final cache = await create(/*...*/);
  await performCacheMaintenance();
  runApp(MyApp());
}
```

### Codecs Personalizados

```dart
// Para objetos complexos, crie codecs específicos
class UserCodec extends CacheCodec<User, Map<String, dynamic>> {
  @override
  String get typeId => 'user:v1'; // Inclua versão no typeId
  
  @override
  User decode(Map<String, dynamic> data) {
    return User.fromJson(data);
  }
  
  @override
  Map<String, dynamic> encode(User value) {
    return value.toJson();
  }
}
```

### Tratamento de Erros

```dart
try {
  final data = await cache.get('key', codec: codec);
  if (data == null) {
    // Chave não existe ou expirou
    print('Cache miss');
  }
} catch (e) {
  // Erro de I/O ou corrupção
  print('Erro ao acessar cache: $e');
  // O cache tenta se recuperar automaticamente
}
```

## Solução de Problemas

### Cache não persiste entre execuções

**Causa:** Possível uso de `CacheLocation.temporary` em dispositivo com pouco espaço.
**Solução:** Use `CacheLocation.support` para dados que devem persistir.

### Arquivo corrompido repetidamente

**Causa:** Possível falha durante escrita (ex: app terminado abruptamente).
**Solução:** O sistema de recuperação automática deve resolver. Se persistir:
```dart
// Force uma limpeza completa
await cache.clear();
```

### Performance lenta com muitas entradas

**Causa:** Arquivo JSON muito grande sendo carregado/gravado a cada operação.
**Soluções:**
- Execute `purgeExpired()` periodicamente
- Use TTL para limitar tempo de vida das entradas
- Considere dividir em múltiplos arquivos de cache por contexto
- Use tags para organizar e limpar grupos de entradas

### Erro "Permission Denied"

**Causa:** Tentativa de acessar diretório sem permissões apropriadas.
**Solução:** Use `CacheLocation.support` que sempre tem permissões adequadas.

### Dados desaparecem no iOS

**Causa:** Uso de `CacheLocation.temporary` - o iOS limpa agressivamente esta pasta.
**Solução:** Use `CacheLocation.support` para dados que devem persistir.

## Contribuindo

Contribuições são bem-vindas! Sinta-se à vontade para abrir issues ou pull requests.

## Licença

Este projeto é de código aberto. Verifique o arquivo LICENSE para mais detalhes.
