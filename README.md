# typed_cache_json

[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](https://github.com/saulogatti/typed_cache_json)

A JSON-based cache backend for the `typed_cache` package. Provides a simple, type-safe, and persistent solution for storing data in a single JSON file, ideal for Flutter and Dart applications that need lightweight persistence.

> **📚 Complete Documentation:** The entire codebase is fully documented with DartDoc comments. Use your IDE's autocomplete or generate documentation with `dart doc` to explore the complete API.

## Features

- **Type-Safe Caching:** Store and retrieve objects with type safety using `CacheCodec`.
- **JSON Persistence:** All data is saved in a single local JSON file.
- **Atomic Writes:** Uses temporary (`.tmp`) and backup (`.bak`) files to prevent data corruption during writes.
- **Automatic Recovery:** Attempts to recover data from backups if the main file is corrupted.
- **Expiration Support (TTL):** Set a time-to-live for your cache entries.
- **Tag-Based Indexing:** Organize and bulk-remove cache entries using tags.
- **Flutter Integration:** Easy path resolution (`ApplicationSupport`, `Documents`, `Temporary`) via `path_provider`.
- **Thread-Safe:** Operations protected by an async mutex, ensuring safety in concurrent environments.
- **Complete Documentation:** Fully documented API with examples and detailed explanations.

## Getting Started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  typed_cache_json:
    git:
      url: https://github.com/saulogatti/typed_cache_json.git
```

## Usage

### Basic Setup (Flutter)

The easiest way to get started with Flutter is using the `create` function:

```dart
import 'package:typed_cache_json/typed_cache_json.dart';

void main() async {
  // Initialize the cache pointing to the application support directory
  final cache = await create(
    location: CacheLocation.support,
    subdir: 'my_app_cache',
    fileName: 'cache.json',
  );
  
  // Now you can use the cache!
}
```

#### Available Locations

The `CacheLocation` enum defines where the cache file will be stored:

- **`CacheLocation.support`** (Recommended): Internal application files not exposed to the user
- **`CacheLocation.temporary`**: Temporary cache; the OS may clean it when needed
- **`CacheLocation.documents`**: User documents (avoid for cache)

### Advanced Configuration

If you need more control, you can create the backend directly:

```dart
import 'package:typed_cache_json/typed_cache_json.dart';
import 'package:typed_cache_json/src/json_file_cache_backend.dart';

void main() async {
  // Create the backend with custom settings
  final backend = await JsonFileCacheBackend.fromLocation(
    location: CacheLocation.support,
    subdir: 'my_app_cache',
    fileName: 'cache.json',
    enableRecovery: true, // Enable automatic recovery (default: true)
  );

  // Create the cache with the backend
  final cache = createTypedCache(
    backend: backend,
    deleteCorruptedEntries: true, // Automatically remove corrupted entries
  );
}
```

### Storing and Retrieving Data

To use the cache, you need to define a `CacheCodec` for your data type:

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

// Using the cache
void main() async {
  final cache = await create(
    location: CacheLocation.support,
    fileName: 'cache.json',
  );
  
  final user = User('Saulo', 30);
  final codec = UserCodec();

  // Save
  await cache.put('user_1', user, codec: codec);

  // Retrieve
  final cachedUser = await cache.get('user_1', codec: codec);
  print('Name: ${cachedUser?.name}, Age: ${cachedUser?.age}');
}
```

### Using the Built-in JSON Codec

For simple data in Map format, you can use the included `CacheJsonCodec`:

```dart
import 'package:typed_cache_json/typed_cache_json.dart';

void main() async {
  final cache = await create(
    location: CacheLocation.support,
    fileName: 'cache.json',
  );
  
  final codec = CacheJsonCodec();
  
  // Save a Map directly
  await cache.put('config', {'theme': 'dark', 'version': 2}, codec: codec);
  
  // Retrieve
  final config = await cache.get('config', codec: codec);
  print('Theme: ${config?['theme']}');
}
```

### Using Tags and TTL

```dart
// Save with 1-hour expiration and tags
await cache.put(
  'session_data', 
  sessionData, 
  codec: myCodec,
  ttl: Duration(hours: 1),
  tags: {'session', 'auth'},
);

// Invalidate everything with the 'session' tag
await cache.invalidateByTag('session');

// Get all keys with a specific tag
final sessionKeys = await cache.keysByTag('session');
print('Session keys: $sessionKeys');
```

### Cleaning Expired Cache

The cache does not automatically remove expired entries from disk (except when you try to read an expired key). To clean the file:

```dart
// Remove all expired entries from the JSON file
final count = await cache.purgeExpired();
print('$count entries removed');
```

### Complete Cache Clear

To remove all cache data:

```dart
// Clear all cache
await cache.clear();
```

## File Structure

The backend maintains a JSON file with the following structure:

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

### Safety Files

During write operations, the backend creates auxiliary files:

- **`cache.json.tmp`**: Temporary file used during write operations
- **`cache.json.bak`**: Backup of the previous file, used for recovery in case of corruption

These files are managed automatically and ensure data integrity.

## Data Recovery

The package includes a robust data recovery system:

1. If the main file is corrupted, it attempts to load from `.bak`
2. If the `.bak` is also corrupted, it tries the `.tmp` file
3. If none work, it initializes an empty cache

You can disable automatic recovery when creating the backend:

```dart
final backend = await JsonFileCacheBackend.fromLocation(
  location: CacheLocation.support,
  fileName: 'cache.json',
  enableRecovery: false, // Disable recovery
);
```

## Logging

For debugging and monitoring, you can enable logs when creating the cache:

```dart
final cache = await create(
  location: CacheLocation.support,
  fileName: 'cache.json',
  logger: (message) => print('[Cache] $message'),
);
```

## Architecture and Internal Workings

### Main Components

The package is organized into specialized components:

#### 1. **JsonFileCacheBackend**
Main backend that implements `CacheBackend` from `typed_cache`. Responsible for:
- Atomic read/write operations
- Entry lifecycle management
- Tag index maintenance
- Automatic failure recovery

#### 2. **AsyncMutex**
Async mutex that serializes concurrent operations. Ensures that:
- I/O operations don't overlap
- Internal state remains consistent
- Errors in one operation don't block others

#### 3. **JsonCacheFile**
Data model that represents the JSON file structure in memory:
- Stores all cache entries
- Maintains reverse tag index for efficient searches
- Serializes/deserializes the JSON file

#### 4. **CacheJsonCodec**
Pre-built codec for simple JSON data (`Map<String, dynamic>`):
- Facilitates storage of configurations and structured data
- No need to create custom codecs for simple data

### Operation Flow

#### Write Operation
```
TypedCache.put() 
  → JsonFileCacheBackend.write()
  → _mutex.synchronized()
    → _load() (load file)
    → _upsertEntry() (update entry and tag index)
    → _save()
      → _atomicWrite() (write .tmp → rename → backup .bak)
```

#### Read Operation
```
TypedCache.get()
  → JsonFileCacheBackend.read()
  → _mutex.synchronized()
    → _load() (load and cache in memory during operation)
    → return entry or null
```

#### Failure Recovery
```
_load() fails
  → _recoverOrEmpty() (if enableRecovery = true)
    → try .bak
    → try .tmp
    → return empty if all fail
```

### Thread-Safety Guarantees

All public operations are protected by `AsyncMutex`, ensuring:
- **Serialization:** Operations execute one at a time, in submission order
- **Consistency:** File and index state always synchronized
- **Isolation:** Errors in one operation don't affect others

### Durability Guarantees

The atomic write protocol ensures:
- **Atomicity:** Complete write or no write (no partial corruption)
- **Automatic Backup:** Previous version always preserved in `.bak`
- **Recovery:** System tries multiple paths before giving up

## Additional Information

### Compatibility

- **Dart SDK**: ^3.10.4
- **Flutter**: Compatible
- **Platforms**: iOS, Android, macOS, Windows, Linux

### API Documentation

All code in this package is fully documented with DartDoc comments. The documentation includes:

- **Detailed Descriptions:** Each class, method, and property has a clear description
- **Usage Examples:** Practical examples for main features
- **Parameters and Returns:** Complete documentation of all parameters and return values
- **Exceptions:** Information about possible errors and how to handle them
- **Implementation Notes:** Details about internal behavior and thread-safety guarantees

#### How to Access Documentation

1. **Via IDE:** Use autocomplete (Ctrl+Space / Cmd+Space) and hover over any symbol to see inline documentation
2. **Generate HTML:** Run `dart doc` in the project directory to generate navigable HTML documentation
3. **Read the Code:** DartDoc comments are visible directly in source files

#### Main Documented Classes

- **`JsonFileCacheBackend`:** Main backend with atomic operations and automatic recovery
- **`AsyncMutex`:** Async mutex implementation for operation serialization
- **`CacheJsonCodec`:** Pre-built codec for simple JSON data
- **`JsonCacheFile`:** Internal cache file model
- **`CacheLocation`:** Enum for choosing cache file location

### Useful Links

- [typed_cache](https://github.com/saulogatti/typed_cache) - Base caching package
- [Repository](https://github.com/saulogatti/typed_cache_json)

### Advanced Resources

For more details about:
- Creating complex codecs
- Custom TTL policies
- Invalidation strategies
- Performance optimizations

See the [typed_cache documentation](https://github.com/saulogatti/typed_cache).

## Best Practices

### Choosing Storage Location

- **Use `CacheLocation.support`** for most cases - it's the recommended location for cache
- **Use `CacheLocation.temporary`** only for truly disposable cache that can be cleared by the OS
- **Avoid `CacheLocation.documents`** for cache - it's for user-visible files

### Tag Management

```dart
// Organize related entries with tags
await cache.put('user_123', userData, codec: codec, tags: {'user', 'session'});
await cache.put('config_123', configData, codec: codec, tags: {'config', 'session'});

// Clear everything related to session at once
await cache.invalidateByTag('session');
```

### Periodic Cleanup

```dart
// Run periodically to keep the file optimized
Future<void> performCacheMaintenance() async {
  final removed = await cache.purgeExpired();
  print('Removed $removed expired entries');
}

// Example: run on app startup
void main() async {
  final cache = await create(/*...*/);
  await performCacheMaintenance();
  runApp(MyApp());
}
```

### Custom Codecs

```dart
// For complex objects, create specific codecs
class UserCodec extends CacheCodec<User, Map<String, dynamic>> {
  @override
  String get typeId => 'user:v1'; // Include version in typeId
  
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

### Error Handling

```dart
try {
  final data = await cache.get('key', codec: codec);
  if (data == null) {
    // Key doesn't exist or has expired
    print('Cache miss');
  }
} catch (e) {
  // I/O error or corruption
  print('Error accessing cache: $e');
  // The cache attempts automatic recovery
}
```

## Troubleshooting

### Cache doesn't persist between runs

**Cause:** Possible use of `CacheLocation.temporary` on device with low space.
**Solution:** Use `CacheLocation.support` for data that should persist.

### File gets corrupted repeatedly

**Cause:** Possible write failure (e.g., app terminated abruptly).
**Solution:** The automatic recovery system should resolve it. If it persists:
```dart
// Force a complete cleanup
await cache.clear();
```

### Slow performance with many entries

**Cause:** Large JSON file being loaded/saved on every operation.
**Solutions:**
- Run `purgeExpired()` periodically
- Use TTL to limit entry lifespan
- Consider splitting into multiple cache files by context
- Use tags to organize and clean groups of entries

### "Permission Denied" error

**Cause:** Attempting to access directory without appropriate permissions.
**Solution:** Use `CacheLocation.support` which always has proper permissions.

### Data disappears on iOS

**Cause:** Use of `CacheLocation.temporary` - iOS aggressively clears this folder.
**Solution:** Use `CacheLocation.support` for data that should persist.

## Contributing

Contributions are welcome! Feel free to open issues or pull requests.

## License

This project is open source. Check the LICENSE file for more details.
