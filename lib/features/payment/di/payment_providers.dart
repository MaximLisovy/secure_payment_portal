import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:secure_payment_portal/features/payment/di/payment_data_source_providers.dart';
import 'package:secure_payment_portal/features/payment/domain/confirm_payment.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_repository.dart';
import 'package:secure_payment_portal/features/security/security.dart';

// The public providers of the payment feature, typed by domain types.

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepositoryImpl(
    remote: ref.watch(paymentRemoteDataSourceProvider),
    platform: ref.watch(paymentPlatformDataSourceProvider),
  ),
);

/// Depends on the security feature only through its public barrel.
final confirmPaymentProvider = Provider<ConfirmPayment>(
  (ref) => ConfirmPayment(
    security: ref.watch(securityStatusRepositoryProvider),
    payments: ref.watch(paymentRepositoryProvider),
    policy: ref.watch(securityPolicyProvider),
  ),
);
