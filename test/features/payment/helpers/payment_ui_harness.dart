import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_config.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/di/payment_data_source_providers.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_notifier.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';

import '../../../helpers/pump_app.dart';

/// A flow that sits in one state and records what the screen asks of it, so a
/// widget test can check one screen without driving the whole state machine.
class FixedFlow extends PaymentFlowNotifier {
  FixedFlow(this.fixed);

  final PaymentFlowState fixed;

  /// The method names the screen called, in order.
  final List<String> calls = [];

  @override
  PaymentFlowState build() => fixed;

  @override
  void begin(PaymentDetails details) => calls.add('begin');

  @override
  Future<void> confirm() async => calls.add('confirm');

  @override
  Future<void> cancel() async => calls.add('cancel');

  @override
  Future<void> retry() async => calls.add('retry');

  @override
  Future<void> newPayment() async => calls.add('newPayment');
}

Override fixedFlowOverride(FixedFlow flow) =>
    paymentFlowProvider.overrideWith(() => flow);

/// The fake backend and device with no latency, so a widget test needs only a
/// few pumps. Pass your own to script a scenario. Unmount the app at the end of
/// a test that started a payment, so the fake's timer is cancelled.
List<Override> instantBackend({
  FakeSecurityPlatformDataSource? security,
  FakePaymentConfig payments = const FakePaymentConfig(
    stepDelay: Duration(milliseconds: 100),
    steps: 4,
  ),
  FakePaymentRemoteDataSource? remote,
}) => [
  securityPlatformDataSourceProvider.overrideWith((ref) {
    final fake = security ?? FakeSecurityPlatformDataSource();
    ref.onDispose(fake.dispose);
    return fake;
  }),
  paymentPlatformDataSourceProvider.overrideWith((ref) {
    final fake = FakePaymentPlatformDataSource(
      config: payments,
      now: () => DateTime.utc(2026, 10, 15, 12),
    );
    ref.onDispose(fake.dispose);
    return fake;
  }),
  paymentRemoteDataSourceProvider.overrideWithValue(
    remote ?? FakePaymentRemoteDataSource(),
  ),
];

extension PumpPaymentPage on WidgetTester {
  /// The real payment page and flow on the instant fakes, pumped until the bill
  /// has loaded and the device check has finished.
  Future<ProviderContainer> pumpPaymentPage({
    required BrandConfig brand,
    FakePaymentConfig payments = const FakePaymentConfig(
      stepDelay: Duration(milliseconds: 100),
      steps: 4,
    ),
    List<Override> overrides = const [],
  }) async {
    final container = await pumpApp(
      const PaymentConfirmationPage(title: 'Test'),
      brand: brand,
      overrides: [
        ...instantBackend(payments: payments),
        ...overrides,
      ],
    );
    for (var i = 0; i < 4; i++) {
      await pump();
    }
    return container;
  }

  /// Removes the app, which disposes the providers and cancels the fakes'
  /// timers. Call it at the end of a test that started a payment.
  Future<void> unmountApp() => pumpWidget(const SizedBox());
}
