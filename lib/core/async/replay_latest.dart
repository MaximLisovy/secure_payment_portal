import 'dart:async';

/// A source of values whose [stream] replays the latest one to every new
/// listener, then follows live updates. It mirrors what a native `StateFlow`
/// behind an `EventChannel` does (emit the current state on listen), so fakes and
/// the real channel sources behave the same.
final class ReplayLatest<T> {
  ReplayLatest(T initial) : _latest = initial;

  T _latest;
  bool _closed = false;
  final StreamController<T> _updates = StreamController<T>.broadcast(
    sync: true,
  );

  T get latest => _latest;

  /// Each listener gets its own replay of [latest] followed by later values, so
  /// no update can slip between the replay and the live subscription.
  Stream<T> get stream => Stream<T>.multi((listener) {
    listener.add(_latest);
    final subscription = _updates.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
  });

  void add(T value) {
    if (_closed) return;
    _latest = value;
    _updates.add(value);
  }

  Future<void> close() {
    _closed = true;
    return _updates.close();
  }
}
