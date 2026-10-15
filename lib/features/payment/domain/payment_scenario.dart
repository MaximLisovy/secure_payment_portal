/// How a simulated payment ends.
enum PaymentScenario { success, declined, processingFailure }

/// Lets a demo or a test choose how simulated payments end.
///
/// Only simulated sources implement it. A real source cannot, so code that holds
/// one is working with a simulation and needs no type check to know it.
abstract interface class PaymentScenarioControl {
  PaymentScenario get scenario;

  void setScenario(PaymentScenario scenario);
}
