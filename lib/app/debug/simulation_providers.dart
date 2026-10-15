import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';
import 'package:secure_payment_portal/features/security/security.dart';

/// Whether any source runs on a simulation right now. The bill backend is
/// simulated by design (there is no backend) and does not count.
final simulationActiveProvider = Provider<bool>(
  (ref) =>
      ref.watch(securitySourceModeProvider) == SourceMode.simulated ||
      ref.watch(paymentSourceModeProvider) == SourceMode.simulated,
);
