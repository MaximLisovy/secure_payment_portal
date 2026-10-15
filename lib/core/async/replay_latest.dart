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
  /// Starts with [initial], which the first listener gets as its replay.
  ///
  /// [onFirstListener] and [onLastCancel] run when the number of live listeners
  /// goes from zero to one and back to zero. They let the owner of an expensive
  /// upstream (a native event channel) open it on demand and close it when
  /// nobody is left, while any number of listeners share it.
  ReplayLatest(
    T initial, {
    this.onFirstListener,
    this.onLastCancel,
    this.forgetOnLastCancel = false,
  }) : _latest = initial,
       _hasValue = true;

  /// Starts with **no value**: a listener gets no replay until the first [add].
  /// For an upstream whose current state is only known once it has spoken, where
  /// a made-up initial value would be a lie.
  ReplayLatest.empty({
    this.onFirstListener,
    this.onLastCancel,
    this.forgetOnLastCancel = false,
  }) : _hasValue = false;

  final void Function()? onFirstListener;
  final void Function()? onLastCancel;

  /// Drop the latest value when the last listener leaves, so that the next
  /// listener is never replayed a value from before the upstream was closed,
  /// which may no longer be true. It waits for the upstream to speak again.
  final bool forgetOnLastCancel;

  T? _latest;
  bool _hasValue;
  bool _closed = false;
  final Set<StreamController<T>> _listeners = {};

  /// Whether there is a value to replay.
  bool get hasValue => _hasValue;

  /// The latest value. Throws a [StateError] if there is none yet.
  T get latest {
    if (!_hasValue) throw StateError('ReplayLatest has no value yet');
    return _latest as T;
  }

  /// A new single-subscription stream per call. It replays [latest] to its
  /// listener, then delivers every later value in order, so no update can slip
  /// between the replay and the live values.
  Stream<T> get stream {
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () {
        if (_hasValue) controller.add(_latest as T);
        if (_closed) {
          unawaited(controller.close());
          return;
        }
        final first = _listeners.isEmpty;
        _listeners.add(controller);
        if (first) onFirstListener?.call();
      },
      onCancel: () {
        final wasListening = _listeners.remove(controller);
        if (wasListening && _listeners.isEmpty) {
          if (forgetOnLastCancel) {
            _latest = null;
            _hasValue = false;
          }
          onLastCancel?.call();
        }
        return Future<void>.value();
      },
    );
    return controller.stream;
  }

  void add(T value) {
    if (_closed) return;
    _latest = value;
    _hasValue = true;
    for (final listener in _listeners.toList()) {
      listener.add(value);
    }
  }

  /// Tells every listener the stream is done, and ignores later values. The
  /// hooks do not run: whoever closes it cleans up its own upstream.
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
