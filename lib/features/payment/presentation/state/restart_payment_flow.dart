import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/security/security.dart';

/// Starts the payment screen over from the bill: reloads it and begins a fresh
/// flow. For a host that changed what the flow runs on, such as the demo panel
/// switching a source between real and simulated, where a half-finished flow
/// would be talking to the old one.
///
/// Screen protection is moved to the current security source first, so the new
/// flow's first device check already sees a protected window.
Future<void> restartPaymentFlow(WidgetRef ref) async {
  await ref.read(secureWindowProvider.notifier).retry();
  if (!ref.context.mounted) return;
  ref
    ..invalidate(paymentFlowProvider)
    ..invalidate(paymentDetailsProvider);
}
