import 'dart:io';

import 'package:test/test.dart';
import 'package:typed_cache/typed_cache.dart';
import 'package:typed_cache_json/src/async_mutex.dart';
import 'package:typed_cache_json/src/json_file_cache_backend.dart';
import 'package:typed_cache_json/src/json_models.dart';

void main() {
  group('AsyncMutex', () {
    test('synchronized executes actions in order', () async {
      final mutex = AsyncMutex();
      final results = <int>[];

      Future<void> action(int value, int delayMs) async {
        await Future.delayed(Duration(milliseconds: delayMs));
        results.add(value);
      }

      await runConcurrentActions(mutex, [() => action(1, 100), () => action(2, 50), () => action(3, 10)]);
      expect(results, [1, 2, 3]);
    });

    test('synchronized returns result from action', () async {
      final mutex = AsyncMutex();
      final result = await mutex.synchronized(() async => 42);
      expect(result, 42);
    });

    test('synchronized propagates errors', () async {
      final mutex = AsyncMutex();
      expect(() => mutex.synchronized(() async => throw Exception('test error')), throwsException);
    });

    test('synchronized continues after error', () async {
      final mutex = AsyncMutex();
      final results = <int>[];

      try {
        await mutex.synchronized(() async => throw Exception('error'));
      } catch (_) {}

      await mutex.synchronized(() async => results.add(1));
      expect(results, [1]);
    });

    test('multiple mutexes are independent', () async {
      final mutex1 = AsyncMutex();
      final mutex2 = AsyncMutex();
      final results = <int>[];

      final future1 = mutex1.synchronized(() async {
        await Future.delayed(Duration(milliseconds: 100));
        results.add(1);
      });

      final future2 = mutex2.synchronized(() async {
        results.add(2);
      });

      await Future.wait([future1, future2]);
      expect(results, [2, 1]);
    });
  });

  group('JsonCacheFile', () {
    test('empty creates empty cache', () {
      final cache = JsonCacheFile.empty<Map<String, dynamic>>();
      expect(cache.schemaVersion, 1);
      expect(cache.entries, isEmpty);
      expect(cache.tagIndex, isEmpty);
    });

    test('toJson serializes correctly', () {
      final cache = JsonCacheFile<Map<String, dynamic>>(
        schemaVersion: 1,
        entries: {
          'key1': CacheEntry(
            key: 'key1',
            typeId: 'test',
            payload: {'data': 'value'},
            createdAtEpochMs: 1000,
            expiresAtEpochMs: 2000,
            tags: {'tag1', 'tag2'},
          ),
        },
        tagIndex: {
          'tag1': {'key1'},
          'tag2': {'key1'},
        },
      );

      final json = cache.toJson();
      expect(json['schemaVersion'], 1);
      expect(json['entries'], isNotEmpty);
      expect(json['tagIndex'], isNotEmpty);
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'schemaVersion': 1,
        'entries': {
          'key1': {
            'key': 'key1',
            'typeId': 'test',
            'payload': {'data': 'value'},
            'createdAt': 1000,
            'expiresAt': 2000,
            'tags': ['tag1', 'tag2'],
          },
        },
        'tagIndex': {
          'tag1': ['key1'],
          'tag2': ['key1'],
        },
      };

      final cache = JsonCacheFile.fromJson(json);
      expect(cache.schemaVersion, 1);
      expect(cache.entries, hasLength(1));
      expect(cache.entries['key1']?.key, 'key1');
      expect(cache.tagIndex, hasLength(2));
    });

    test('roundtrip serialization', () {
      final original = JsonCacheFile<Map<String, dynamic>>(
        schemaVersion: 1,
        entries: {
          'key1': CacheEntry(
            key: 'key1',
            typeId: 'test',
            payload: {'data': 'value'},
            createdAtEpochMs: 1000,
            expiresAtEpochMs: 2000,
            tags: {'tag1'},
          ),
        },
        tagIndex: {
          'tag1': {'key1'},
        },
      );

      final json = original.toJson();
      final deserialized = JsonCacheFile.fromJson(json);

      expect(deserialized.schemaVersion, original.schemaVersion);
      expect(deserialized.entries.keys, original.entries.keys);
      expect(deserialized.tagIndex, original.tagIndex);
    });
  });

  group('JsonFileCacheBackend', () {
    late Directory tempDir;
    late File cacheFile;
    late JsonFileCacheBackend backend;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp();
      cacheFile = File('${tempDir.path}/cache.json');
      backend = JsonFileCacheBackend(file: cacheFile);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('write and read entry', () async {
      final entry = CacheEntry<Map<String, dynamic>>(
        key: 'test_key',
        typeId: 'test_type',
        payload: {'data': 'value'},
        createdAtEpochMs: 1000,
        expiresAtEpochMs: null,
        tags: const {},
      );

      await backend.write(entry);
      final read = await backend.read<Map<String, dynamic>>('test_key');

      expect(read, isNotNull);
      expect(read!.key, 'test_key');
      expect(read.payload, {'data': 'value'});
    });

    test('read non-existent entry returns null', () async {
      final read = await backend.read<Map<String, dynamic>>('non_existent');
      expect(read, isNull);
    });

    test('delete removes entry', () async {
      final entry = CacheEntry<Map<String, dynamic>>(
        key: 'test_key',
        typeId: 'test_type',
        payload: {'data': 'value'},
        createdAtEpochMs: 1000,
        expiresAtEpochMs: null,
        tags: const {},
      );

      await backend.write(entry);
      await backend.delete('test_key');
      final read = await backend.read<Map<String, dynamic>>('test_key');

      expect(read, isNull);
    });

    test('clear removes all entries', () async {
      final entry1 = CacheEntry<Map<String, dynamic>>(
        key: 'key1',
        typeId: 'test',
        payload: {'data': '1'},
        createdAtEpochMs: 1000,
        expiresAtEpochMs: null,
        tags: const {},
      );

      final entry2 = CacheEntry<Map<String, dynamic>>(
        key: 'key2',
        typeId: 'test',
        payload: {'data': '2'},
        createdAtEpochMs: 1000,
        expiresAtEpochMs: null,
        tags: const {},
      );

      await backend.write(entry1);
      await backend.write(entry2);
      await backend.clear();

      expect(await backend.read<Map<String, dynamic>>('key1'), isNull);
      expect(await backend.read<Map<String, dynamic>>('key2'), isNull);
    });

    test('keysByTag returns tagged keys', () async {
      final entry1 = CacheEntry<Map<String, dynamic>>(
        key: 'key1',
        typeId: 'test',
        payload: {'data': '1'},
        createdAtEpochMs: 1000,
        expiresAtEpochMs: null,
        tags: {'session', 'auth'},
      );

      final entry2 = CacheEntry<Map<String, dynamic>>(
        key: 'key2',
        typeId: 'test',
        payload: {'data': '2'},
        createdAtEpochMs: 1000,
        expiresAtEpochMs: null,
        tags: {'session'},
      );

      await backend.write(entry1);
      await backend.write(entry2);

      final sessionKeys = await backend.keysByTag('session');
      expect(sessionKeys, containsAll(['key1', 'key2']));

      final authKeys = await backend.keysByTag('auth');
      expect(authKeys, ['key1']);
    });

    test('deleteTag removes tag from entries', () async {
      final entry = CacheEntry<Map<String, dynamic>>(
        key: 'key1',
        typeId: 'test',
        payload: {'data': '1'},
        createdAtEpochMs: 1000,
        expiresAtEpochMs: null,
        tags: {'session', 'auth'},
      );

      await backend.write(entry);
      await backend.deleteTag('auth');

      final keys = await backend.keysByTag('auth');
      expect(keys, isEmpty);

      final sessionKeys = await backend.keysByTag('session');
      expect(sessionKeys, ['key1']);
    });

    test('purgeExpired removes expired entries', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final unexpiredEntry = CacheEntry<Map<String, dynamic>>(
        key: 'unexpired',
        typeId: 'test',
        payload: {'data': '1'},
        createdAtEpochMs: now,
        expiresAtEpochMs: now + 10000,
        tags: const {},
      );

      final expiredEntry = CacheEntry<Map<String, dynamic>>(
        key: 'expired',
        typeId: 'test',
        payload: {'data': '2'},
        createdAtEpochMs: now,
        expiresAtEpochMs: now - 1000,
        tags: const {},
      );

      await backend.write(unexpiredEntry);
      await backend.write(expiredEntry);

      final removed = await backend.purgeExpired(now);

      expect(removed, 1);
      expect(await backend.read<Map<String, dynamic>>('unexpired'), isNotNull);
      expect(await backend.read<Map<String, dynamic>>('expired'), isNull);
    });

    test('atomic write creates backup file', () async {
      // Write initial content
      final entry = CacheEntry<Map<String, dynamic>>(
        key: 'key1',
        typeId: 'test',
        payload: {'data': 'initial'},
        createdAtEpochMs: 1000,
        expiresAtEpochMs: null,
        tags: const {},
      );

      await backend.write(entry);
      expect(await cacheFile.exists(), isTrue);

      // Write new content - should create backup
      final entry2 = CacheEntry<Map<String, dynamic>>(
        key: 'key2',
        typeId: 'test',
        payload: {'data': 'updated'},
        createdAtEpochMs: 2000,
        expiresAtEpochMs: null,
        tags: const {},
      );

      await backend.write(entry2);

      final bakFile = File('${cacheFile.path}.bak');
      expect(await bakFile.exists(), isTrue);
    });

    test('recovery from corrupted file uses backup', () async {
      // Write initial data
      final entry = CacheEntry<Map<String, dynamic>>(
        key: 'key1',
        typeId: 'test',
        payload: {'data': 'original'},
        createdAtEpochMs: 1000,
        expiresAtEpochMs: null,
        tags: const {},
      );

      await backend.write(entry);

      // Write update to create backup
      await backend.write(
        CacheEntry<Map<String, dynamic>>(
          key: 'key2',
          typeId: 'test',
          payload: {'data': 'update'},
          createdAtEpochMs: 2000,
          expiresAtEpochMs: null,
          tags: const {},
        ),
      );

      // Corrupt main file
      await cacheFile.writeAsString('invalid json {]');

      // Create new backend with recovery enabled
      final recoveredBackend = JsonFileCacheBackend(file: cacheFile, enableRecovery: true);

      // Should recover from backup with original data
      final recovered = await recoveredBackend.read<Map<String, dynamic>>('key1');
      expect(recovered, isNotNull);
      expect(recovered!.payload, {'data': 'original'});
    });

    test('concurrent writes are serialized', () async {
      final results = <String>[];

      await Future.wait([
        () async {
          await backend.write(
            CacheEntry<Map<String, dynamic>>(
              key: 'key1',
              typeId: 'test',
              payload: {'n': 1},
              createdAtEpochMs: 1000,
              expiresAtEpochMs: null,
              tags: const {},
            ),
          );
          results.add('write1');
        }(),
        () async {
          await backend.write(
            CacheEntry<Map<String, dynamic>>(
              key: 'key2',
              typeId: 'test',
              payload: {'n': 2},
              createdAtEpochMs: 1000,
              expiresAtEpochMs: null,
              tags: const {},
            ),
          );
          results.add('write2');
        }(),
        () async {
          await Future.delayed(Duration(milliseconds: 10));
          await backend.read<Map<String, dynamic>>('key1');
          results.add('read1');
        }(),
      ]);

      // Both writes should succeed without corruption
      expect(await backend.read<Map<String, dynamic>>('key1'), isNotNull);
      expect(await backend.read<Map<String, dynamic>>('key2'), isNotNull);
    });
  });
}

Future<void> delayedAction(int value, int delayMs, List<int> results) async {
  await Future.delayed(Duration(milliseconds: delayMs));
  results.add(value);
}

Future<void> executeM(AsyncMutex mutex, Future<void> Function() action) => mutex.synchronized(action);

Future<void> runConcurrentActions(AsyncMutex mutex, List<Future<void> Function()> actions) async {
  await Future.wait(actions.map((action) => executeM(mutex, action)));
}
