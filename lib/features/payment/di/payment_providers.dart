import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/logging/logger_provider.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/features/payment/data/controls/bill_backend_control.dart';
import 'package:secure_payment_portal/features/payment/data/controls/payment_scenario_control.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_attempt_id.dart';
import 'package:secure_payment_portal/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:secure_payment_portal/features/payment/di/payment_data_source_providers.dart';
import 'package:secure_payment_portal/features/payment/domain/confirm_payment.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_repository.dart';
import 'package:secure_payment_portal/features/payment/presentation/config/payment_screen_config.dart';
import 'package:secure_payment_portal/features/security/security.dart';

export 'package:secure_payment_portal/features/payment/data/controls/bill_backend_control.dart';
export 'package:secure_payment_portal/features/payment/data/controls/payment_scenario_control.dart';

// Repositories use domain interfaces; debug controls use simulation-only data contracts.

/// The screen's layout. The feature never knows which brand it runs
/// in: the composition root overrides this with the active brand's config.
final paymentScreenConfigProvider = Provider<PaymentScreenConfig>(
  (ref) => throw UnimplementedError(
    'paymentScreenConfigProvider must be overridden by the app.',
  ),
);

/// The host supplies a request independently of theme and section configuration.
final paymentIdProvider = Provider<String>(
  (ref) => throw UnimplementedError(
    'paymentIdProvider must be overridden by the host.',
  ),
);

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepositoryImpl(
    remote: ref.watch(paymentRemoteDataSourceProvider),
    platform: ref.watch(paymentPlatformDataSourceProvider),
    logger: ref.watch(loggerProvider),
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

/// The controls of the simulated payment processing, or null when the feature
/// runs on the real foreground service. Only the simulation implements the
/// interface, so nothing needs a downcast.
final paymentScenarioControlProvider = Provider<PaymentScenarioControl?>(
  (ref) => ref.watch(paymentSourceModeProvider) == SourceMode.simulated
      ? ref.watch(simulatedPaymentPlatformDataSourceProvider)
      : null,
);

/// The controls of the bill backend, which is simulated for good.
final billBackendControlProvider = Provider<BillBackendControl>(
  (ref) => ref.watch(fakePaymentRemoteDataSourceProvider),
);

/// A fresh execution ID for each user confirmation; override with a sequence in tests.
final paymentAttemptIdFactoryProvider = Provider<String Function()>(
  (ref) => createPaymentAttemptId,
);
