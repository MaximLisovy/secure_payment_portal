import 'package:secure_payment_portal/features/payment/domain/payment_scenario.dart';

/// Lets a demo or a test choose how simulated payments end.
///
/// Only simulated sources implement it. A real source cannot, so code that holds
/// one is working with a simulation and needs no type check to know it.
abstract interface class PaymentScenarioControl {
  PaymentScenario get scenario;

  void setScenario(PaymentScenario scenario);
}
