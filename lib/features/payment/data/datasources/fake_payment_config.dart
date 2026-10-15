import 'package:secure_payment_portal/features/payment/domain/payment_scenario.dart';

/// The deterministic script of the fake payment processing: [steps] progress
/// updates [stepDelay] apart, then the end of the [scenario] one delay later.
final class FakePaymentConfig {
  const FakePaymentConfig({
    this.stepDelay = const Duration(milliseconds: 400),
    this.steps = 10,
    this.scenario = PaymentScenario.success,
  }) : assert(steps > 0, 'at least one step');

  final Duration stepDelay;
  final int steps;

  /// How it ends to begin with. A [PaymentScenarioControl] can change it later.
  final PaymentScenario scenario;

  /// From `startPayment` to the terminal state.
  Duration get totalDuration => stepDelay * (steps + 1);
}
