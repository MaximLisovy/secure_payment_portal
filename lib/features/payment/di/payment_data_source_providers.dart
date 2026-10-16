import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/logging/logger_provider.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/channel_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_config.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/mappers/payment_details_mapper.dart';
import 'package:secure_payment_portal/features/payment/presentation/config/demo_bill.dart';

/// How long fetching a bill takes, so the UI has a loading state to show.
const Duration fakeBillLatency = Duration(milliseconds: 600);

// Wiring only; not part of the feature's public barrel, except the mode.

/// The script of the simulated processing; override it to start a test on a
/// declined or failing payment.
final fakePaymentConfigProvider = Provider<FakePaymentConfig>(
  (ref) => const FakePaymentConfig(),
);

/// The host supplies demo data; features carry no tenant catalog.
final demoBillCatalogProvider = Provider<List<DemoBill>>((ref) => const []);

/// The bill backend stays a fake for good: there is no backend. Typed as the
/// fake because it is also the [BillBackendControl].
final fakePaymentRemoteDataSourceProvider =
    Provider<FakePaymentRemoteDataSource>(
      (ref) => FakePaymentRemoteDataSource(
        latency: fakeBillLatency,
        bills: {
          for (final bill in ref.watch(demoBillCatalogProvider))
            bill.id: PaymentDetailsMapper.toDto(bill.toDetails()),
        },
      ),
    );

final paymentRemoteDataSourceProvider = Provider<PaymentRemoteDataSource>(
  (ref) => ref.watch(fakePaymentRemoteDataSourceProvider),
);

/// The channels to the Kotlin foreground service. Plain providers, so a test
/// can replace them.
final paymentMethodChannelProvider = Provider<MethodChannel>(
  (ref) => const MethodChannel(PaymentChannel.methods),
);

final paymentProgressEventChannelProvider = Provider<EventChannel>(
  (ref) => const EventChannel(PaymentChannel.progressEvents),
);

/// The channel-based source: the real foreground service. It is the default.
/// Where there is no native side (iOS, desktop, plain `flutter test`) starting a
/// payment fails as unsupported; a debug build can switch to the simulation.
/// Nullable so a test can override it with null and get the simulation back as
/// the only option.
final realPaymentPlatformDataSourceProvider =
    Provider<PaymentPlatformDataSource?>((ref) {
      final source = ChannelPaymentPlatformDataSource(
        methods: ref.watch(paymentMethodChannelProvider),
        progressEvents: ref.watch(paymentProgressEventChannelProvider),
        logger: ref.watch(loggerProvider),
      );
      ref.onDispose(source.dispose);
      return source;
    });

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
