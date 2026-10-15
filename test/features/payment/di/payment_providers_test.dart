import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_bills.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_config.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/di/payment_data_source_providers.dart';
import 'package:secure_payment_portal/features/payment/di/payment_providers.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_failures.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';
import 'package:secure_payment_portal/features/security/security.dart';
import '../../../helpers/fake_time.dart';

const _step = Duration(milliseconds: 100);

/// The default wiring, with the scan and bill latency removed and a short
/// payment script, so the whole feature runs in a few fake milliseconds.
ProviderContainer _container({
  FakePaymentOutcome outcome = FakePaymentOutcome.success,
  FakeSecurityPlatformDataSource? device,
}) {
  return ProviderContainer.test(
    overrides: [
      paymentRemoteDataSourceProvider.overrideWithValue(
        FakePaymentRemoteDataSource(),
      ),
      fakePaymentConfigProvider.overrideWithValue(
        FakePaymentConfig(stepDelay: _step, steps: 2, outcome: outcome),
      ),
      securityPlatformDataSourceProvider.overrideWithValue(
        device ?? FakeSecurityPlatformDataSource(),
      ),
    ],
  );
}

void main() {
  testWidgets(
    'confirming through the default wiring runs a payment to its receipt',
    (tester) async {
      final container = _container();
      final payments = container.read(paymentRepositoryProvider);
      final seen = <PaymentProgress>[];
      final subscription = payments.watchProgress().listen(seen.add);
      final details = (await payments.getPaymentDetails(
        FakeBills.retailOrderId,
      )).valueOrNull;

      final result = await container.read(confirmPaymentProvider)(details!);
      await tester.pump(_step * 3);

      expect(result.isSuccess, isTrue);
      expect(seen.first, const PaymentIdle());
      expect(seen.last, isA<PaymentSucceeded>());
      expect(
        (seen.last as PaymentSucceeded).result.amount,
        const Money.minor(10939, Currency.usd),
      );
      await settle(tester, subscription.cancel());
    },
  );

  testWidgets('a declined script surfaces as a typed failure', (tester) async {
    final container = _container(outcome: FakePaymentOutcome.declined);
    final payments = container.read(paymentRepositoryProvider);
    final seen = <PaymentProgress>[];
    final subscription = payments.watchProgress().listen(seen.add);
    final details = (await payments.getPaymentDetails(
      FakeBills.utilityBillId,
    )).valueOrNull;

    await container.read(confirmPaymentProvider)(details!);
    await tester.pump(_step * 3);

    expect(seen.last, const PaymentFailed(PaymentDeclinedFailure()));
    await settle(tester, subscription.cancel());
  });

  testWidgets('a rooted device never reaches the payment platform', (
    tester,
  ) async {
    final container = _container(
      device: FakeSecurityPlatformDataSource()
        ..setRoot(DetectionWire.detected, signals: [RootReasonCodes.suBinary]),
    );
    final payments = container.read(paymentRepositoryProvider);
    final seen = <PaymentProgress>[];
    final subscription = payments.watchProgress().listen(seen.add);
    final details = (await payments.getPaymentDetails(
      FakeBills.retailOrderId,
    )).valueOrNull;

    final result = await container.read(confirmPaymentProvider)(details!);
    await tester.pump(_step * 3);

    expect(
      result.failureOrNull,
      SecurityBlockedFailure(SecurityBlockReason.rootDetected),
    );
    expect(seen, [
      const PaymentIdle(),
    ], reason: 'processing must never have started');
    await settle(tester, subscription.cancel());
  });

  test('by default the bill backend is a fake with a loading delay', () {
    final container = ProviderContainer.test();

    expect(
      container.read(paymentRemoteDataSourceProvider),
      isA<FakePaymentRemoteDataSource>().having(
        (f) => f.latency,
        'latency',
        fakeBillLatency,
      ),
    );
  });
}
