import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_config.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_remote_data_source.dart';

/// How long fetching a bill takes, so the UI has a loading state to show.
const Duration fakeBillLatency = Duration(milliseconds: 600);

/// Wiring only. The script of the simulated processing; override it to play a
/// declined or failing payment.
final fakePaymentConfigProvider = Provider<FakePaymentConfig>(
  (ref) => const FakePaymentConfig(),
);

/// The bill backend stays a fake for good: there is no backend.
final paymentRemoteDataSourceProvider = Provider<PaymentRemoteDataSource>(
  (ref) => FakePaymentRemoteDataSource(latency: fakeBillLatency),
);

/// A fake until the native milestone: swap this body for the channel-based
/// source, which honours the same contract. Nothing else changes.
final paymentPlatformDataSourceProvider = Provider<PaymentPlatformDataSource>((
  ref,
) {
  final fake = FakePaymentPlatformDataSource(
    config: ref.watch(fakePaymentConfigProvider),
  );
  ref.onDispose(fake.dispose);
  return fake;
});
