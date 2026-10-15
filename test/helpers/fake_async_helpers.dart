import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the outcome of a future inside `fakeAsync`, where `await` is not
/// available: create the probe, flush the microtasks (or elapse time), then look.
final class FutureProbe<T> {
  FutureProbe(Future<T> future) {
    future.then<void>(
      (value) {
        _value = value;
        _isDone = true;
      },
      onError: (Object error) {
        _error = error;
        _isDone = true;
      },
    );
  }

  bool _isDone = false;
  T? _value;
  Object? _error;

  bool get isDone => _isDone;

  /// What the future failed with, or null if it succeeded or is still pending.
  Object? get error => _error;

  /// The value of a future that completed normally. Fails the test otherwise.
  T get value {
    if (!_isDone) fail('the future has not completed');
    final error = _error;
    if (error != null) fail('the future failed with $error');
    return _value as T;
  }
}

/// `fakeAsync` does not complain about a timer left running when the test ends
/// (a widget test does), so say it out loud.
void expectNoPendingTimers(FakeAsync async) {
  expect(
    async.periodicTimerCount + async.nonPeriodicTimerCount,
    0,
    reason: async.pendingTimersDebugString.join('\n'),
  );
}
