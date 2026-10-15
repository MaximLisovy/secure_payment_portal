import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_bills.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_config.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/di/payment_data_source_providers.dart';
import 'package:secure_payment_portal/features/payment/di/payment_providers.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_failures.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_scenario.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';
import 'package:secure_payment_portal/features/security/security.dart';

import '../../../helpers/fake_async_helpers.dart';

const _step = Duration(milliseconds: 100);

/// The default wiring, with the scan and bill latency removed and a short
/// payment script, so the whole feature runs in a few fake milliseconds.
ProviderContainer _container({
  PaymentScenario outcome = PaymentScenario.success,
  FakeSecurityPlatformDataSource? device,
}) {
  return ProviderContainer.test(
    overrides: [
      paymentRemoteDataSourceProvider.overrideWithValue(
        FakePaymentRemoteDataSource(),
      ),
      fakePaymentConfigProvider.overrideWithValue(
        FakePaymentConfig(stepDelay: _step, steps: 2, scenario: outcome),
      ),
      securityPlatformDataSourceProvider.overrideWithValue(
        device ?? FakeSecurityPlatformDataSource(),
      ),
    ],
  );
}

/// Loads [billId] and confirms it, inside `fakeAsync`. Returns what the
/// progress stream reported and how the confirm ended.
({List<PaymentProgress> seen, Result<void> confirmed}) _pay(
  FakeAsync async,
  ProviderContainer container,
  String billId, {
  bool protectWindow = true,
}) {
  final payments = container.read(paymentRepositoryProvider);
  final seen = <PaymentProgress>[];
  payments.watchProgress().listen(seen.add);

  // What `SecureScreen` does when the payment page is shown.
  if (protectWindow) {
    unawaited(container.read(secureWindowControllerProvider).enable());
    async.flushMicrotasks();
  }

  final loaded = FutureProbe(payments.getPaymentDetails(billId));
  async.flushMicrotasks();
  final PaymentDetails details = loaded.value.fold(
    (bill) => bill,
    (failure) => fail('the demo bill did not load: ${failure.messageKey}'),
  );

  final confirm = FutureProbe(container.read(confirmPaymentProvider)(details));
  async.elapse(_step * 3);
  return (seen: seen, confirmed: confirm.value);
}

void main() {
  test(
    'confirming through the default wiring runs a payment to its receipt',
    () {
      fakeAsync((async) {
        final container = _container();

        final paid = _pay(async, container, FakeBills.retailOrderId);

        expect(paid.confirmed.isSuccess, isTrue);
        expect(paid.seen.first, const PaymentIdle());
        expect(paid.seen.last, isA<PaymentSucceeded>());
        expect(
          (paid.seen.last as PaymentSucceeded).result.amount,
          const Money.minor(10939, Currency.usd),
        );
        expectNoPendingTimers(async);
      });
    },
  );

  test('a declined script surfaces as a typed failure', () {
    fakeAsync((async) {
      final container = _container(outcome: PaymentScenario.declined);

      final paid = _pay(async, container, FakeBills.utilityBillId);

      expect(paid.seen.last, const PaymentFailed(PaymentDeclinedFailure()));
    });
  });

  test('a rooted device never reaches the payment platform', () {
    fakeAsync((async) {
      final container = _container(
        device: FakeSecurityPlatformDataSource()
          ..setRoot(
            DetectionWire.detected,
            signals: [RootReasonCodes.suBinary],
          ),
      );

      final paid = _pay(async, container, FakeBills.retailOrderId);

      expect(
        paid.confirmed.failureOrNull,
        SecurityBlockedFailure(SecurityBlockReason.rootDetected),
      );
      expect(paid.seen, [
        const PaymentIdle(),
      ], reason: 'processing must never have started');
    });
  });

  test('an unprotected window never reaches the payment platform', () {
    fakeAsync((async) {
      final container = _container();

      final paid = _pay(
        async,
        container,
        FakeBills.retailOrderId,
        protectWindow: false,
      );

      expect(
        paid.confirmed.failureOrNull,
        SecurityBlockedFailure(SecurityBlockReason.screenProtectionUnavailable),
      );
      expect(paid.seen, [const PaymentIdle()]);
    });
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
