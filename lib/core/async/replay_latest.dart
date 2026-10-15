import 'dart:async';

/// A source of values whose [stream] replays the latest one to every new
/// listener, then follows live updates. It mirrors what a native `StateFlow`
/// behind an `EventChannel` does (emit the current state on listen), so fakes and
/// the real channel sources behave the same.
///
/// Each listener owns a plain `StreamController`, and this class only fans
/// values out to them. That keeps it testable under a fake clock: nested
/// forwarding, or a `Stream.multi`, loses the done event under `fakeAsync`, and
/// a `cancel()` whose `onCancel` returns nothing completes on the root zone,
/// which a fake clock never runs.
final class ReplayLatest<T> {
  ReplayLatest(T initial) : _latest = initial;

  T _latest;
  bool _closed = false;
  final Set<StreamController<T>> _listeners = {};

  T get latest => _latest;

  /// A new single-subscription stream per call. It replays [latest] to its
  /// listener, then delivers every later value in order, so no update can slip
  /// between the replay and the live values.
  Stream<T> get stream {
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () {
        controller.add(_latest);
        if (_closed) {
          unawaited(controller.close());
        } else {
          _listeners.add(controller);
        }
      },
      onCancel: () {
        _listeners.remove(controller);
        return Future<void>.value();
      },
    );
    return controller.stream;
  }

  void add(T value) {
    if (_closed) return;
    _latest = value;
    for (final listener in _listeners.toList()) {
      listener.add(value);
    }
  }

  /// Tells every listener the stream is done, and ignores later values.
  Future<void> close() {
    _closed = true;
    final listeners = _listeners.toList();
    _listeners.clear();
    for (final listener in listeners) {
      unawaited(listener.close());
    }
    return Future<void>.value();
  }
}
