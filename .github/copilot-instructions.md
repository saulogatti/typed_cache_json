# typed_cache_json - AI Coding Agent Instructions

## Project Overview

This is a **JSON-based backend implementation** for the `typed_cache` package. It provides persistent, typed caching with atomic file operations, auto-recovery, and tag-based indexing. The project is a **Dart/Flutter library** (not an application).

**Key Dependency:** Extends `typed_cache` from https://github.com/saulogatti/typed_cache.git - familiarize yourself with its `CacheBackend`, `CacheEntry<E>`, and `CacheCodec<T, E>` abstractions.

## Architecture

### Core Components

1. **`JsonFileCacheBackend`** ([json_file_cache_backend.dart](../lib/src/json_file_cache_backend.dart))
   - Implements `CacheBackend` from `typed_cache`
   - **Atomic writes:** Uses `.tmp` and `.bak` files to prevent corruption
   - **Recovery:** Falls back to `.bak` → `.tmp` → empty if main file corrupted
   - **Thread-safe:** All operations wrapped in `AsyncMutex.synchronized()`
   - Factory method: `fromLocation()` resolves Flutter platform paths

2. **`JsonCacheFile<E>`** ([json_models.dart](../lib/src/json_models.dart))
   - In-memory representation of the JSON file structure
   - Schema: `{schemaVersion, entries: Map<key, CacheEntry>, tagIndex: Map<tag, Set<key>>}`
   - Generic over `E` (payload type), serialized as `Map<String, dynamic>`

3. **`AsyncMutex`** ([async_mutex.dart](../lib/src/async_mutex.dart))
   - Simple future-chaining mutex for serializing async operations
   - Critical for preventing race conditions in concurrent file I/O

4. **Public API** ([json_utils.dart](../lib/src/json_utils.dart))
   - `create()` - Main entry point, returns configured `TypedCache`
   - `CacheLocation` enum - Maps to path_provider directories

### Data Flow

```
User → TypedCache.put() → JsonFileCacheBackend.write()
  → _mutex.synchronized() → _load() → _upsertEntry() → _save()
  → _atomicWrite() → .tmp → rename → .bak cleanup
```

**Recovery Path:** `_load()` fails → `_recoverOrEmpty()` tries `.bak`, `.tmp` → returns empty if all fail

## Critical Patterns

### 1. Generic Type Handling
```dart
// Backend is generic over payload type E (e.g., Map<String, dynamic>)
final backend = JsonFileCacheBackend<E>(...);

// In serialization, payload is treated as E (not concrete type)
CacheEntry<E>(payload: json['payload'] as E, ...)
```

### 2. Atomic File Operations
Never write directly to the main file. Always use:
```dart
await _atomicWrite(file, content);  // writes to .tmp, copies old to .bak, renames
```

### 3. Tag Index Maintenance
When modifying entries, **always** update the reverse tag index:
```dart
_removeKeyFromTags(db, key, oldEntry.tags);  // before removing/updating
db.tagIndex[tag] ??= <String>{}.add(key);    // when adding
```

### 4. Mutex Usage
**Every** public backend method must wrap in mutex:
```dart
@override
Future<void> someMethod() => _mutex.synchronized(() async {
  // actual implementation
});
```

## Testing Strategy

- Tests focus on `AsyncMutex` concurrency guarantees (see [typed_cache_json_test.dart](../test/typed_cache_json_test.dart))
- No integration tests for file I/O yet - main testing happens in `typed_cache` package
- When adding tests, use `flutter test` (not `dart test`) due to Flutter SDK dependency

## Development Workflow

### Commands
```bash
# Run tests
flutter test

# Format code (REQUIRED - use tool)
dart format .

# Analyze
dart analyze

# Build runner (if using code generation in future)
dart run build_runner build --delete-conflicting-outputs
```

### Dependencies
- **Local dev:** Comment out git dependency, use `path: ../typed_cache` in pubspec.yaml
- **Commit:** Revert to git dependency before pushing
- Adding packages: `flutter pub add <package>` (note: Flutter, not Dart)

## Code Conventions

- **Immutability:** All backend classes use `final` fields
- **Class modifiers:** Use `final class` for concrete implementations (prevents inheritance)
- **Naming:** `snake_case` files, `PascalCase` classes, `camelCase` members
- **Exports:** Only export through [typed_cache_json.dart](../lib/typed_cache_json.dart) - keep `src/` private
- **Null safety:** Leverage sound null safety; use `?`, `??`, `!` appropriately

## Common Pitfalls

1. **Don't bypass mutex** - Causes race conditions in concurrent scenarios
2. **Don't forget tag index cleanup** - Leads to orphaned keys in `tagIndex`
3. **Don't assume file exists** - Always check or handle `FileSystemException`
4. **Don't expose `src/` classes** - Public API is `create()` and re-exported `TypedCache`

## Flutter-Specific Notes

- Uses `path_provider` for cross-platform paths (iOS/Android/Desktop)
- `CacheLocation.support` (ApplicationSupport) is **recommended** - not user-visible
- If adding platform-specific code, update [flutter_path.dart](../lib/src/flutter_path.dart)

## Version & Publishing

- Current: `v0.2.1`
- `publish_to: none` - Git-only distribution
- SDK constraint: `^3.10.4` (uses latest Dart 3 features)
