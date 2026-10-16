import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/core/logging/logger_provider.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/channel_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_bills.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_config.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_progress_dto.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/start_payment_request_dto.dart';
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
import '../../../helpers/recording_logger.dart';
import '../helpers/payment_fixtures.dart';

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
      realSecurityPlatformDataSourceProvider.overrideWithValue(
        device ?? FakeSecurityPlatformDataSource(),
      ),
      // The tests below run the feature on the simulation, so say so: the
      // channel source is the default and has no native side here.
      realPaymentPlatformDataSourceProvider.overrideWithValue(null),
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

  final confirm = FutureProbe(
    container.read(confirmPaymentProvider)(details, attemptId: 'attempt-1'),
  );
  async.elapse(_step * 3);
  return (seen: seen, confirmed: confirm.value);
}

/// A processing source whose progress stream fails with something no failure covers.
class _BrokenProgressSource implements PaymentPlatformDataSource {
  @override
  Stream<PaymentProgressDto> watchProgress() =>
      Stream<PaymentProgressDto>.error(StateError('card 4111'));

  @override
  Future<void> startPayment(StartPaymentRequestDto request) async {}

  @override
  Future<void> cancelPayment({required String attemptId}) async {}

  @override
  Future<void> preparePayment() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

      expect(
        paid.seen.last,
        const PaymentFailed(
          PaymentDeclinedFailure(),
          paymentId: FakeBills.utilityBillId,
          attemptId: 'attempt-1',
        ),
      );
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

  group('the source mode', () {
    test('by default the feature runs on the channel-based source', () {
      final container = ProviderContainer.test();

      expect(container.read(paymentSourceModeProvider), SourceMode.real);
      expect(
        container.read(paymentPlatformDataSourceProvider),
        isA<ChannelPaymentPlatformDataSource>(),
      );
      expect(container.read(paymentScenarioControlProvider), isNull);
    });

    test('the repository and the channel source use the app logger', () async {
      final logger = RecordingLogger();
      const methods = MethodChannel('test/payment/logging');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methods, (call) async {
            if (call.method == PaymentChannel.requestNotificationPermission) {
              return NotificationPermissionWire.granted;
            }
            throw PlatformException(code: 'BROKEN', message: 'card 4111');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(methods, null),
      );
      final container = ProviderContainer.test(
        overrides: [
          loggerProvider.overrideWithValue(logger),
          paymentMethodChannelProvider.overrideWithValue(methods),
        ],
      );

      final result = await container
          .read(paymentRepositoryProvider)
          .startPayment(sampleDetails, attemptId: 'attempt-1');

      expect(result.isSuccess, isFalse);
      expect(logger.warnings.single.message, contains('BROKEN'));
      expect(logger.entries.single.everything, isNot(contains('4111')));
    });

    test(
      'the repository logs an error nothing covers through the app logger',
      () async {
        final logger = RecordingLogger();
        final container = ProviderContainer.test(
          overrides: [
            loggerProvider.overrideWithValue(logger),
            realPaymentPlatformDataSourceProvider.overrideWithValue(
              _BrokenProgressSource(),
            ),
          ],
        );

        final first = await container
            .read(paymentRepositoryProvider)
            .watchProgress()
            .first;

        expect(first, isA<PaymentFailed>());
        expect(logger.errors.single.error, StateError);
      },
    );

    test('the channels are plain providers, so a test can replace them', () {
      const methods = MethodChannel('test/payment');
      const events = EventChannel('test/payment/events');
      final container = ProviderContainer.test(
        overrides: [
          paymentMethodChannelProvider.overrideWithValue(methods),
          paymentProgressEventChannelProvider.overrideWithValue(events),
        ],
      );

      expect(container.read(paymentMethodChannelProvider), same(methods));
      expect(container.read(paymentProgressEventChannelProvider), same(events));
    });

    ProviderContainer containerWithReal(FakePaymentPlatformDataSource real) =>
        ProviderContainer.test(
          overrides: [
            realPaymentPlatformDataSourceProvider.overrideWithValue(real),
          ],
        );

    test(
      'is simulated while no real source is wired, with controls to steer it',
      () {
        final container = ProviderContainer.test(
          overrides: [
            realPaymentPlatformDataSourceProvider.overrideWithValue(null),
          ],
        );

        expect(container.read(paymentSourceModeProvider), SourceMode.simulated);
        expect(
          container.read(paymentScenarioControlProvider),
          same(container.read(paymentPlatformDataSourceProvider)),
          reason: 'the controls steer the very source the feature runs on',
        );
      },
    );

    test(
      'is real once a real source is wired, and then offers no controls',
      () {
        final real = FakePaymentPlatformDataSource();
        final container = containerWithReal(real);

        expect(container.read(paymentSourceModeProvider), SourceMode.real);
        expect(container.read(paymentPlatformDataSourceProvider), same(real));
        expect(container.read(paymentScenarioControlProvider), isNull);
      },
    );

    test(
      'switching to the simulation swaps the source and brings the controls',
      () {
        final real = FakePaymentPlatformDataSource();
        final container = containerWithReal(real);

        container
            .read(paymentSourceModeProvider.notifier)
            .select(SourceMode.simulated);

        expect(
          container.read(paymentPlatformDataSourceProvider),
          isNot(same(real)),
        );
        expect(container.read(paymentScenarioControlProvider), isNotNull);
      },
    );

    test('the bill backend is always simulated and always steerable', () {
      final container = containerWithReal(FakePaymentPlatformDataSource());

      expect(
        container.read(billBackendControlProvider),
        same(container.read(paymentRemoteDataSourceProvider)),
      );
    });
  });
}
