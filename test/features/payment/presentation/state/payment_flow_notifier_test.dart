import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/start_payment_request_dto.dart';
import 'package:secure_payment_portal/features/payment/di/payment_providers.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_failures.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_repository.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_result.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_scenario.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/scan_dwell_provider.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/security.dart';

import '../../../../helpers/fake_async_helpers.dart';
import '../../../security/helpers/security_fixtures.dart';
import '../../helpers/flow_harness.dart';
import '../../helpers/payment_fixtures.dart';

class _MockSecurity extends Mock implements SecurityStatusRepository {}

class _MockPayments extends Mock implements PaymentRepository {}

final _receipt = PaymentResult(
  paymentId: 'bill-1',
  transactionId: 'FAKE-TX-000001',
  amount: const Money.minor(1100, Currency.usd),
  completedAt: harnessClock,
  attemptId: 'attempt-1',
);

const _idle = PaymentFlowIdle();
const _checking = PaymentFlowSecurityCheck();
const _ready = PaymentFlowReady();
const _confirming = PaymentFlowConfirming();

PaymentFlowProcessing _processing(int percent, {bool cancelling = false}) =>
    PaymentFlowProcessing(percent: percent, cancelRequested: cancelling);

PaymentFlowBlocked _blocked(SecurityBlockReason reason) =>
    PaymentFlowBlocked(reason);

/// Runs a whole payment to its end on [h]'s fake processing, as an earlier visit
/// to the page would have.
void _payDirectly(FlowHarness h, FakeAsync async, {String billId = 'bill-1'}) {
  unawaited(
    h.payments.startPayment(
      StartPaymentRequestDto(
        paymentId: billId,
        amountMinor: 1100,
        currency: 'USD',
        attemptId: 'attempt-1',
      ),
    ),
  );
  async.elapse(harnessStep * (harnessSteps + 2));
}

void main() {
  setUpAll(() {
    registerFallbackValue(sampleDetails);
  });

  group('a payment that goes through', () {
    test('walks the machine from idle to the receipt', () {
      fakeAsync((async) {
        final h = FlowHarness.create();
        h.protectWindow(async);

        h.begin(async);
        h.confirm(async, harnessStep * (harnessSteps + 1));

        expect(h.states, [
          _idle,
          _checking,
          _ready,
          _confirming,
          _processing(0),
          _processing(50),
          _processing(100),
          PaymentFlowSuccess(_receipt),
        ]);
        expectNoPendingTimers(async);
      });
    });

    test('starting the same bill twice does nothing the second time', () {
      fakeAsync((async) {
        final h = FlowHarness.create();
        h.protectWindow(async);
        h.begin(async);
        final before = List.of(h.states);

        h.begin(async);

        expect(h.states, before);
      });
    });

    test('a different bill restarts the flow', () {
      fakeAsync((async) {
        final h = FlowHarness.create();
        h.protectWindow(async);
        h.begin(async);
        h.states.clear();

        h.begin(async, detailsWith([usdItem(500)]));

        expect(h.states, [_idle, _checking, _ready]);
      });
    });

    test('a double tap confirms once', () {
      fakeAsync((async) {
        final h = FlowHarness.create();
        h.protectWindow(async);
        h.begin(async);

        unawaited(h.flow.confirm());
        unawaited(h.flow.confirm());
        async.elapse(harnessStep * (harnessSteps + 1));

        expect(h.states.whereType<PaymentFlowFailure>(), isEmpty);
        expect(h.states.last, PaymentFlowSuccess(_receipt));
      });
    });

    test('confirm does nothing before the device is ready', () {
      fakeAsync((async) {
        final h = FlowHarness.create();
        h.protectWindow(async);

        h.confirm(async);
        h.begin(async);
        h.states.clear();
        h.security.setRoot(
          DetectionWire.detected,
          signals: [RootReasonCodes.suBinary],
        );

        expect(h.states, isEmpty);
        expect(h.flow.state, _ready);
      });
    });
  });

  group('a payment that does not go through', () {
    test('a decline ends in a typed failure', () {
      fakeAsync((async) {
        final h = FlowHarness.create(outcome: PaymentScenario.declined);
        h.protectWindow(async);
        h.begin(async);

        h.confirm(async, harnessStep * (harnessSteps + 1));

        expect(
          h.states.last,
          const PaymentFlowFailure(PaymentDeclinedFailure()),
        );
      });
    });

    test('a failure while processing ends in a typed failure', () {
      fakeAsync((async) {
        final h = FlowHarness.create(
          outcome: PaymentScenario.processingFailure,
        );
        h.protectWindow(async);
        h.begin(async);

        h.confirm(async, harnessStep * (harnessSteps + 1));

        expect(
          h.states.last,
          const PaymentFlowFailure(PaymentProcessingFailure()),
        );
      });
    });

    test('retry after a failure checks the device again and is ready', () {
      fakeAsync((async) {
        final h = FlowHarness.create(outcome: PaymentScenario.declined);
        h.protectWindow(async);
        h.begin(async);
        h.confirm(async, harnessStep * (harnessSteps + 1));
        h.states.clear();

        unawaited(h.flow.retry());
        async.flushMicrotasks();

        expect(h.states, [_checking, _ready]);
      });
    });

    test('a failure from starting goes to failure, not to blocked', () {
      fakeAsync((async) {
        final h = FlowHarness.create();
        h.protectWindow(async);
        h.begin(async);
        _payDirectly(h, async, billId: 'someone-else');
        // Something else is already paying: the platform refuses a second start.
        unawaited(h.payments.startPayment(sampleRequest));
        async.flushMicrotasks();
        h.states.clear();

        h.confirm(async);

        expect(h.states, [
          _confirming,
          const PaymentFlowFailure(PaymentInProgressFailure()),
        ]);
      });
    });
  });

  group('the device blocks payment', () {
    test('a rooted device is blocked for good', () {
      fakeAsync((async) {
        final h = FlowHarness.create(
          security: FakeSecurityPlatformDataSource()
            ..setRoot(
              DetectionWire.detected,
              signals: [RootReasonCodes.suBinary],
            ),
        );
        h.protectWindow(async);

        h.begin(async);
        final blocked = List.of(h.states);
        unawaited(h.flow.retry());
        async.flushMicrotasks();

        expect(blocked, [
          _idle,
          _checking,
          _blocked(SecurityBlockReason.rootDetected),
        ]);
        expect(h.states, blocked, reason: 'a root block cannot be retried');
      });
    });

    test('a root that cannot be verified blocks too', () {
      fakeAsync((async) {
        final h = FlowHarness.create(
          security: FakeSecurityPlatformDataSource()
            ..setRoot(DetectionWire.unknown),
        );
        h.protectWindow(async);

        h.begin(async);

        expect(h.states.last, _blocked(SecurityBlockReason.rootUnverifiable));
      });
    });

    test(
      'a recording that starts blocks, and lifts by itself when it ends',
      () {
        fakeAsync((async) {
          final h = FlowHarness.create();
          h.protectWindow(async);
          h.begin(async);

          h.security.setScreenRecording(DetectionWire.detected);
          async.flushMicrotasks();
          h.security.setScreenRecording(DetectionWire.notDetected);
          async.flushMicrotasks();

          expect(h.states, [
            _idle,
            _checking,
            _ready,
            _blocked(SecurityBlockReason.screenRecording),
            _ready,
          ]);
        });
      },
    );

    test('a recording already in progress blocks from the start', () {
      fakeAsync((async) {
        final h = FlowHarness.create(
          security: FakeSecurityPlatformDataSource()
            ..setScreenRecording(DetectionWire.detected),
        );
        h.protectWindow(async);

        h.begin(async);

        expect(h.states.last, _blocked(SecurityBlockReason.screenRecording));
      });
    });

    test('check again after a recording block runs a fresh check', () {
      fakeAsync((async) {
        final h = FlowHarness.create(
          security: FakeSecurityPlatformDataSource()
            ..setScreenRecording(DetectionWire.detected),
        );
        h.protectWindow(async);
        h.begin(async);
        h.states.clear();

        unawaited(h.flow.retry());
        async.flushMicrotasks();

        expect(h.states, [
          _checking,
          _blocked(SecurityBlockReason.screenRecording),
        ]);
      });
    });

    test('a window that cannot be protected blocks, and recovers on retry', () {
      fakeAsync((async) {
        final device = FakeSecurityPlatformDataSource()
          ..setScreenProtectionAvailable(available: false);
        final h = FlowHarness.create(security: device);
        h.protectWindow(async);

        h.begin(async);
        expect(
          h.states.last,
          _blocked(SecurityBlockReason.screenProtectionUnavailable),
        );

        device.setScreenProtectionAvailable(available: true);
        unawaited(h.flow.retry());
        async.flushMicrotasks();

        expect(h.states.sublist(h.states.length - 3), [
          _blocked(SecurityBlockReason.screenProtectionUnavailable),
          _checking,
          _ready,
        ]);
        expect(device.secureWindowCount, 1);
      });
    });

    // The race this group closes: the bill can load before the platform has
    // answered the request for protection. "Not answered yet" is not "failed".
    group('while the secure window has not answered yet', () {
      const windowDelay = Duration(milliseconds: 300);

      /// What `SecureScreen` does in `initState`, with no flush: the answer is
      /// still on its way when the bill arrives.
      void askForProtection(FlowHarness h) {
        unawaited(h.container.read(secureWindowProvider.notifier).acquire());
      }

      test('the device is not evaluated, so it is not blocked', () {
        fakeAsync((async) {
          final device = FakeSecurityPlatformDataSource(
            windowLatency: windowDelay,
          );
          final h = FlowHarness.create(security: device);
          askForProtection(h);

          h.begin(async);
          async.elapse(windowDelay ~/ 2);

          expect(h.flow.state, _checking);
          expect(h.states, isNot(contains(isA<PaymentFlowBlocked>())));

          async.elapse(windowDelay);

          expect(h.flow.state, _ready);
          expect(h.states, isNot(contains(isA<PaymentFlowBlocked>())));
        });
      });

      test('an explicit failure of the window blocks once it is known', () {
        fakeAsync((async) {
          final device = FakeSecurityPlatformDataSource(
            windowLatency: windowDelay,
          )..setScreenProtectionAvailable(available: false);
          final h = FlowHarness.create(security: device);
          askForProtection(h);

          h.begin(async);
          async.elapse(windowDelay ~/ 2);
          expect(h.flow.state, _checking);

          async.elapse(windowDelay);

          expect(
            h.flow.state,
            _blocked(SecurityBlockReason.screenProtectionUnavailable),
          );
          expect(h.states, isNot(contains(_ready)));
        });
      });

      test('"Check again" waits for the new request too', () {
        fakeAsync((async) {
          final device = FakeSecurityPlatformDataSource(
            windowLatency: windowDelay,
          )..setScreenProtectionAvailable(available: false);
          final h = FlowHarness.create(security: device);
          askForProtection(h);
          h.begin(async);
          async.elapse(windowDelay * 2);
          expect(
            h.flow.state,
            _blocked(SecurityBlockReason.screenProtectionUnavailable),
          );
          final before = h.states.length;

          device.setScreenProtectionAvailable(available: true);
          unawaited(h.flow.retry());
          async.elapse(windowDelay ~/ 2);
          expect(
            h.states.length,
            before,
            reason: 'nothing changes while the new request is pending',
          );

          async.elapse(windowDelay);

          expect(h.states.sublist(before), [_checking, _ready]);
        });
      });

      test('a flow dropped while waiting never reads the device', () {
        fakeAsync((async) {
          final device = FakeSecurityPlatformDataSource(
            windowLatency: windowDelay,
          );
          final h = FlowHarness.create(security: device);
          askForProtection(h);
          h.begin(async);

          h.container.dispose();
          async.elapse(windowDelay * 2);

          expect(h.states.last, _checking);
        });
      });
    });

    test(
      'no window protection at all blocks, as when nobody called SecureScreen',
      () {
        fakeAsync((async) {
          final h = FlowHarness.create();

          h.begin(async);

          expect(
            h.states.last,
            _blocked(SecurityBlockReason.screenProtectionUnavailable),
          );
        });
      },
    );

    test(
      'a recording that starts after confirming does not cancel the payment',
      () {
        fakeAsync((async) {
          final h = FlowHarness.create();
          h.protectWindow(async);
          h.begin(async);
          h.confirm(async, harnessStep);
          expect(h.flow.state, isA<PaymentFlowProcessing>());

          h.security.setScreenRecording(DetectionWire.detected);
          async.elapse(harnessStep * (harnessSteps + 1));

          expect(h.states.whereType<PaymentFlowBlocked>(), isEmpty);
          expect(h.states.last, PaymentFlowSuccess(_receipt));
        });
      },
    );

    test(
      'a block that appears between ready and confirm stops the payment',
      () {
        fakeAsync((async) {
          final security = _MockSecurity();
          final h = FlowHarness.create(
            overrides: [
              securityStatusRepositoryProvider.overrideWithValue(security),
            ],
          );
          // The stream still says all is well, but a fresh read says recording.
          when(
            () => security.watchStatus(),
          ).thenAnswer((_) => Stream.value(cleanStatus));
          when(() => security.getStatus()).thenAnswer(
            (_) async => const Success<SecurityStatus>(
              SecurityStatus(
                root: RootClear(),
                screenRecording: Detection.detected,
                windowProtection: WindowProtection.active,
              ),
            ),
          );
          h.begin(async);
          expect(h.flow.state, _ready);

          h.confirm(async);

          expect(h.states.sublist(h.states.length - 2), [
            _confirming,
            _blocked(SecurityBlockReason.screenRecording),
          ]);
          final platform = <String>[];
          h.payments.watchProgress().listen((dto) => platform.add(dto.state));
          async.flushMicrotasks();
          expect(platform, [
            PaymentChannel.stateIdle,
          ], reason: 'processing must never start');
        });
      },
    );
  });

  group('cancelling', () {
    test(
      'cancel is confirmed by the platform, and a repeat tap is ignored',
      () {
        fakeAsync((async) {
          final h = FlowHarness.create();
          h.protectWindow(async);
          h.begin(async);
          h.confirm(async);

          unawaited(h.flow.cancel());
          unawaited(h.flow.cancel());
          async.flushMicrotasks();

          expect(h.states.sublist(h.states.length - 3), [
            _processing(0),
            _processing(0, cancelling: true),
            const PaymentFlowCancelled(),
          ]);
          expectNoPendingTimers(async);
        });
      },
    );

    test('retry after a cancel is ready again', () {
      fakeAsync((async) {
        final h = FlowHarness.create();
        h.protectWindow(async);
        h.begin(async);
        h.confirm(async);
        unawaited(h.flow.cancel());
        async.flushMicrotasks();
        h.states.clear();

        unawaited(h.flow.retry());
        async.flushMicrotasks();

        expect(h.states, [_checking, _ready]);
      });
    });

    test('a cancel request that fails lets the user try again', () {
      fakeAsync((async) {
        final payments = _MockPayments();
        when(
          () => payments.preparePayment(),
        ).thenAnswer((_) async => Success.unit);
        final progress = StreamController<PaymentProgress>();
        final h = FlowHarness.create(
          overrides: [paymentRepositoryProvider.overrideWithValue(payments)],
        );
        when(() => payments.watchProgress()).thenAnswer((_) => progress.stream);
        when(
          () => payments.startPayment(any(), attemptId: 'attempt-1'),
        ).thenAnswer((_) async => Success.unit);
        when(() => payments.cancelPayment(attemptId: 'attempt-1')).thenAnswer(
          (_) async =>
              const Err<void>(PlatformFailure(ChannelErrorCodes.internal)),
        );
        h.protectWindow(async);
        h.begin(async);
        progress.add(const PaymentIdle());
        async.flushMicrotasks();
        h.confirm(async);
        progress.add(
          const PaymentInProgress('bill-1', 30, attemptId: 'attempt-1'),
        );
        async.flushMicrotasks();

        unawaited(h.flow.cancel());
        async.flushMicrotasks();

        expect(
          h.states.last,
          const PaymentFlowProcessing(
            percent: 30,
            cancellationFailure: PlatformFailure(ChannelErrorCodes.internal),
          ),
        );
        unawaited(progress.close());
      });
    });
  });

  group('success starts over', () {
    test('a new payment after a receipt checks the device again', () {
      fakeAsync((async) {
        final h = FlowHarness.create();
        h.protectWindow(async);
        h.begin(async);
        h.confirm(async, harnessStep * (harnessSteps + 1));
        h.states.clear();

        unawaited(h.flow.repeatPayment());
        async.flushMicrotasks();

        expect(h.states, [_checking, _ready]);
      });
    });

    test('new payment is only for a finished payment', () {
      fakeAsync((async) {
        final h = FlowHarness.create();
        h.protectWindow(async);
        h.begin(async);
        final before = List.of(h.states);

        unawaited(h.flow.repeatPayment());
        async.flushMicrotasks();

        expect(h.states, before);
      });
    });
  });

  group('what the platform already knows when the page opens', () {
    test(
      'a payment still running for this bill is resumed without a new check',
      () {
        fakeAsync((async) {
          final h = FlowHarness.create();
          unawaited(h.payments.startPayment(sampleRequest));
          async.elapse(harnessStep);

          h.begin(async);

          expect(h.states, [_idle, _processing(50)]);

          async.elapse(harnessStep * 2);
          expect(h.states.last, PaymentFlowSuccess(_receipt));
        });
      },
    );

    test(
      'a receipt for this bill is shown instead of letting it be paid twice',
      () {
        fakeAsync((async) {
          final h = FlowHarness.create();
          _payDirectly(h, async);

          h.begin(async);

          expect(h.states, [_idle, PaymentFlowSuccess(_receipt)]);
        });
      },
    );

    test('a receipt for another bill is ignored and the device is checked', () {
      fakeAsync((async) {
        final h = FlowHarness.create();
        h.protectWindow(async);
        _payDirectly(h, async, billId: 'someone-else');

        h.begin(async);

        expect(h.states, [_idle, _checking, _ready]);
      });
    });

    test('a failed or cancelled run left over is ignored', () {
      fakeAsync((async) {
        final declined = FlowHarness.create(outcome: PaymentScenario.declined);
        declined.protectWindow(async);
        _payDirectly(declined, async);

        declined.begin(async);

        expect(declined.states, [_idle, _checking, _ready]);
      });
    });
  });

  group('the scan dwell', () {
    const revolution = Duration(seconds: 2);
    final dwell = [scanDwellProvider.overrideWithValue(revolution)];

    test('a quick verdict waits for the end of the first revolution', () {
      fakeAsync((async) {
        final h = FlowHarness.create(overrides: dwell);
        h.protectWindow(async);

        h.begin(async);
        expect(h.states, [_idle, _checking]);

        async.elapse(revolution - const Duration(milliseconds: 1));
        expect(h.states, [_idle, _checking]);

        async.elapse(const Duration(milliseconds: 1));
        expect(h.states, [_idle, _checking, _ready]);
        expectNoPendingTimers(async);
      });
    });

    test(
      'a verdict after the first revolution waits for the end of the next',
      () {
        fakeAsync((async) {
          final h = FlowHarness.create(
            security: FakeSecurityPlatformDataSource(
              latency: const Duration(milliseconds: 2500),
            ),
            overrides: dwell,
          );
          h.protectWindow(async);

          h.begin(async);
          async.elapse(const Duration(milliseconds: 2500));
          expect(h.states.last, _checking, reason: 'known, but mid-revolution');

          async.elapse(const Duration(milliseconds: 1499));
          expect(h.states.last, _checking);
          async.elapse(const Duration(milliseconds: 1));
          expect(h.states.last, _ready);
        });
      },
    );

    test('a block waits like a pass does', () {
      fakeAsync((async) {
        final h = FlowHarness.create(
          security: FakeSecurityPlatformDataSource(status: rootedDto),
          overrides: dwell,
        );
        h.protectWindow(async);

        h.begin(async);
        async.elapse(revolution - const Duration(milliseconds: 1));
        expect(h.states.whereType<PaymentFlowBlocked>(), isEmpty);

        async.elapse(const Duration(milliseconds: 1));
        expect(h.states.last, _blocked(SecurityBlockReason.rootDetected));
      });
    });

    test('the latest verdict is the one shown, with nothing in between', () {
      fakeAsync((async) {
        final h = FlowHarness.create(overrides: dwell);
        h.protectWindow(async);
        h.begin(async);

        async.elapse(const Duration(seconds: 1));
        h.security.setScreenRecording(DetectionWire.detected);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));

        expect(h.states, [
          _idle,
          _checking,
          _blocked(SecurityBlockReason.screenRecording),
        ]);
      });
    });

    test('after the verdict is shown, changes apply at once', () {
      fakeAsync((async) {
        final h = FlowHarness.create(overrides: dwell);
        h.protectWindow(async);
        h.begin(async);
        async.elapse(revolution);
        expect(h.states.last, _ready);

        h.security.setScreenRecording(DetectionWire.detected);
        async.flushMicrotasks();

        expect(h.states.last, _blocked(SecurityBlockReason.screenRecording));
      });
    });

    test('confirming is not delayed', () {
      fakeAsync((async) {
        final h = FlowHarness.create(overrides: dwell);
        h.protectWindow(async);
        h.begin(async);
        async.elapse(revolution);
        h.states.clear();

        h.confirm(async);

        expect(h.states, [_confirming, _processing(0)]);
      });
    });

    test('checking again waits for a revolution again', () {
      fakeAsync((async) {
        final h = FlowHarness.create(overrides: dwell);
        h.protectWindow(async);
        h.security.setScreenRecording(DetectionWire.detected);
        h.begin(async);
        async.elapse(revolution);
        expect(h.states.last, _blocked(SecurityBlockReason.screenRecording));
        h.states.clear();

        unawaited(h.flow.retry());
        async.flushMicrotasks();
        async.elapse(revolution - const Duration(milliseconds: 1));
        expect(h.states, [_checking]);

        async.elapse(const Duration(milliseconds: 1));
        expect(h.states, [
          _checking,
          _blocked(SecurityBlockReason.screenRecording),
        ]);
      });
    });

    test('a new bill starts a new revolution', () {
      fakeAsync((async) {
        final h = FlowHarness.create(overrides: dwell);
        h.protectWindow(async);
        h.begin(async);
        async.elapse(const Duration(milliseconds: 1500));

        h.begin(async, detailsWith([usdItem(500)]));
        async.elapse(const Duration(milliseconds: 1500));
        expect(
          h.states.last,
          _checking,
          reason: 'only 1.5 s into the new bill',
        );

        async.elapse(const Duration(milliseconds: 500));
        expect(h.states.last, _ready);
      });
    });

    test('with no dwell the verdict is shown at once', () {
      fakeAsync((async) {
        final h = FlowHarness.create(
          overrides: [scanDwellProvider.overrideWithValue(Duration.zero)],
        );
        h.protectWindow(async);

        h.begin(async);

        expect(h.states, [_idle, _checking, _ready]);
      });
    });

    test('leaving the page before any verdict leaves no timer behind', () {
      fakeAsync((async) {
        final h = FlowHarness.create(
          security: FakeSecurityPlatformDataSource(
            latency: const Duration(seconds: 10),
          ),
          overrides: dwell,
        );
        h.protectWindow(async);
        h.begin(async);
        async.elapse(const Duration(seconds: 1));

        h.container.dispose();
        async.elapse(const Duration(seconds: 30));

        expectNoPendingTimers(async);
      });
    });

    test('leaving the page mid-revolution leaves no timer and no change', () {
      fakeAsync((async) {
        final h = FlowHarness.create(overrides: dwell);
        h.protectWindow(async);
        h.begin(async);
        async.elapse(const Duration(seconds: 1));
        final before = List.of(h.states);

        h.container.dispose();
        async.elapse(const Duration(seconds: 5));

        expect(h.states, before);
        expectNoPendingTimers(async);
      });
    });
  });

  group('lifetime', () {
    test(
      'after the container is disposed nothing changes and nothing throws',
      () {
        fakeAsync((async) {
          final h = FlowHarness.create();
          h.protectWindow(async);
          h.begin(async);
          final before = List.of(h.states);

          h.container.dispose();
          h.security.setScreenRecording(DetectionWire.detected);
          async.flushMicrotasks();
          unawaited(h.payments.startPayment(sampleRequest));
          async.elapse(harnessStep * 4);

          expect(h.states, before);
        });
      },
    );
  });
}
