import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';

/// Starts the payment screen over from the bill: reloads it and begins a fresh
/// flow. For a host that changed what the flow runs on, such as the demo panel
/// switching a source between real and simulated, where a half-finished flow
/// would be talking to the old one.
void restartPaymentFlow(WidgetRef ref) {
  ref
    ..invalidate(paymentFlowProvider)
    ..invalidate(paymentDetailsProvider);
}
