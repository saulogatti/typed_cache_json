# typed_cache_json example

Small Flutter app that stores maps in one JSON file with `typed_cache_json`.

```dart
final cache = await create(
  location: CacheLocation.support,
  subdir: 'typed_cache_json_example',
  fileName: 'cache.json',
);

await cache.put('note-1', {'key': 'note-1', 'text': 'Hello, cache'}, tags: {'notes'});
final note = await cache.get('note-1');
```

`create` selects the built-in JSON codec, so values are `Map<String, dynamic>`.
The file is written under the application support directory.

## Run

```bash
cd example
flutter pub get
flutter run
```

Targets match the package: Android, iOS, Windows, macOS, and Linux.
Web is not supported.
The screen covers `put`, `get`, `getOrFetch`, tag invalidation, TTL, and `purgeExpired`.
Entries remain in `cache.json` after the app closes.
