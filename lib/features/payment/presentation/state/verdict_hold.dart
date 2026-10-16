import 'dart:async';

/// Holds the latest value until the end of a revolution, then hands it over.
///
/// It is the timing of the scan dwell, apart from the flow it serves: started
/// with the length of a revolution it ticks at the end of each one, and a value
/// offered in between is kept (the latest one) until the next tick releases it.
/// A tick with nothing offered waits for the following one, so a value that
/// arrives late is still shown at the end of the revolution it arrived in.
///
/// Timers only, no clock: it runs under fake time in tests.
final class VerdictHold<T> {
  VerdictHold(this._release);

  final void Function(T value) _release;

  Timer? _revolutions;
  T? _held;

  /// Whether a revolution is being waited out.
  bool get isHolding => _revolutions != null;

  /// Starts waiting out revolutions of [revolution]; a zero length holds nothing.
  /// Whatever was held before is dropped.
  void start(Duration revolution) {
    stop();
    if (revolution <= Duration.zero) return;
    _revolutions = Timer.periodic(revolution, (_) => _tick());
  }

  /// Keeps [value] for the next tick, replacing any earlier one.
  void hold(T value) => _held = value;

  /// Gives up on waiting and drops what is held.
  void stop() {
    _revolutions?.cancel();
    _revolutions = null;
    _held = null;
  }

  void _tick() {
    final value = _held;
    if (value == null) return;
    stop();
    _release(value);
  }
}
