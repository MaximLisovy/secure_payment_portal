/// How the simulated processing ends.
enum FakePaymentOutcome { success, declined, processingFailure }

/// The deterministic script of the fake payment processing: [steps] progress
/// updates [stepDelay] apart, then the [outcome] one delay later.
final class FakePaymentConfig {
  const FakePaymentConfig({
    this.stepDelay = const Duration(milliseconds: 400),
    this.steps = 10,
    this.outcome = FakePaymentOutcome.success,
  }) : assert(steps > 0, 'at least one step');

  final Duration stepDelay;
  final int steps;
  final FakePaymentOutcome outcome;

  /// From `startPayment` to the terminal state.
  Duration get totalDuration => stepDelay * (steps + 1);
}
