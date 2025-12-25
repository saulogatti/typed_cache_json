import 'package:test/test.dart';
import 'package:typed_cache_json/src/async_mutex.dart';

void main() {
  setUp(() {});

  test('synchronized executes actions in order', () async {
    final mutex = AsyncMutex();
    final results = <int>[];

    Future<void> action(int value, int delayMs) async {
      await Future.delayed(Duration(milliseconds: delayMs));
      results.add(value);
    }

    await runConcurrentActions(mutex, [
      () => action(1, 100),
      () => action(2, 50),
      () => action(3, 10),
    ]);
    expect(results, [1, 2, 3]);
  });
}

Future<void> delayedAction(int value, int delayMs, List<int> results) async {
  await Future.delayed(Duration(milliseconds: delayMs));
  results.add(value);
}

Future<void> executeM(AsyncMutex mutex, Future<void> Function() action) =>
    mutex.synchronized(action);

Future<void> runConcurrentActions(
  AsyncMutex mutex,
  List<Future<void> Function()> actions,
) async {
  await Future.wait(actions.map((action) => executeM(mutex, action)));
}
