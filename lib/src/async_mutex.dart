import 'dart:async';

/// A simple asynchronous mutex for serializing concurrent operations.
///
/// This class ensures that asynchronous operations are executed one at a time,
/// in the order they are submitted. It's particularly useful for preventing
/// race conditions in file I/O operations or other critical sections.
///
/// ## Implementation Details
///
/// The mutex maintains a chain of futures (tail). When [synchronized] is called,
/// the new operation is appended to the end of this chain, ensuring sequential
/// execution even in highly concurrent scenarios.
///
/// ## Thread Safety
///
/// While Dart is single-threaded, this mutex is essential for serializing
/// async operations that may interleave due to `await` points.
///
/// ## Example
///
/// ```dart
/// final mutex = AsyncMutex();
/// final results = <int>[];
///
/// // These operations will execute in order, despite concurrent calls
/// await Future.wait([
///   mutex.synchronized(() async {
///     await Future.delayed(Duration(milliseconds: 100));
///     results.add(1);
///   }),
///   mutex.synchronized(() async {
///     await Future.delayed(Duration(milliseconds: 50));
///     results.add(2);
///   }),
///   mutex.synchronized(() async {
///     results.add(3);
///   }),
/// ]);
///
/// print(results); // [1, 2, 3] - order preserved
/// ```
final class AsyncMutex {
  /// The tail of the operation chain. New operations are appended here.
  Future<void> _tail = Future.value();

  /// Executes the given [action] exclusively, waiting for all previous
  /// operations to complete first.
  ///
  /// This method ensures that:
  /// 1. [action] waits for all previously submitted actions to complete
  /// 2. [action] completes before any subsequently submitted action starts
  /// 3. Errors in [action] are propagated to the caller without blocking
  ///    subsequent operations
  ///
  /// ## Parameters
  ///
  /// - [action]: An asynchronous function to execute exclusively
  ///
  /// ## Returns
  ///
  /// A future that completes with the result of [action], or completes with
  /// an error if [action] throws.
  ///
  /// ## Error Handling
  ///
  /// If [action] throws an error, the error is propagated to the caller
  /// while still allowing subsequent operations to proceed.
  Future<T> synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
