import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_config.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_remote_data_source.dart';

/// How long fetching a bill takes, so the UI has a loading state to show.
const Duration fakeBillLatency = Duration(milliseconds: 600);

// Wiring only; not part of the feature's public barrel, except the mode.

/// The script of the simulated processing; override it to start a test on a
/// declined or failing payment.
final fakePaymentConfigProvider = Provider<FakePaymentConfig>(
  (ref) => const FakePaymentConfig(),
);

/// The bill backend stays a fake for good: there is no backend. Typed as the
/// fake because it is also the [BillBackendControl].
final fakePaymentRemoteDataSourceProvider =
    Provider<FakePaymentRemoteDataSource>(
      (ref) => FakePaymentRemoteDataSource(latency: fakeBillLatency),
    );

final paymentRemoteDataSourceProvider = Provider<PaymentRemoteDataSource>(
  (ref) => ref.watch(fakePaymentRemoteDataSourceProvider),
);

/// The foreground-service source. Null until the native milestone wires it.
final realPaymentPlatformDataSourceProvider =
    Provider<PaymentPlatformDataSource?>((ref) => null);

/// The simulated processing. Typed as the fake on purpose: it is both the data
/// source and the [PaymentScenarioControl]. Override this one, not the
/// selection below, to script a payment in a test.
final simulatedPaymentPlatformDataSourceProvider =
    Provider<FakePaymentPlatformDataSource>((ref) {
      final fake = FakePaymentPlatformDataSource(
        config: ref.watch(fakePaymentConfigProvider),
      );
      ref.onDispose(fake.dispose);
      return fake;
    });

/// Real by default once a real source exists; a debug build may switch.
final paymentSourceModeProvider =
    NotifierProvider<SourceModeNotifier, SourceMode>(
      () => SourceModeNotifier(
        isRealAvailable: (ref) =>
            ref.read(realPaymentPlatformDataSourceProvider) != null,
      ),
    );

/// The source the feature runs on right now. Override this in tests to replace
/// the selection altogether.
final paymentPlatformDataSourceProvider = Provider<PaymentPlatformDataSource>((
  ref,
) {
  final real = ref.watch(realPaymentPlatformDataSourceProvider);
  if (real != null && ref.watch(paymentSourceModeProvider) == SourceMode.real) {
    return real;
  }
  return ref.watch(simulatedPaymentPlatformDataSourceProvider);
});
