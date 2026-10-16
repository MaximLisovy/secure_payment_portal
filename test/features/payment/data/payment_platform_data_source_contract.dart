import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_progress_dto.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/start_payment_request_dto.dart';

import '../../../helpers/fake_async_helpers.dart';

const _request = StartPaymentRequestDto(
  paymentId: 'bill-1',
  amountMinor: 1100,
  currency: 'USD',
  attemptId: 'attempt-1',
);

const _terminalStates = {
  PaymentChannel.stateSucceeded,
  PaymentChannel.stateFailed,
  PaymentChannel.stateCancelled,
};

List<PaymentProgressDto> _record(PaymentPlatformDataSource source) {
  final events = <PaymentProgressDto>[];
  source.watchProgress().listen(events.add);
  return events;
}

Matcher _platformError(String code) =>
    isA<PlatformCallException>().having((e) => e.code, 'code', code);

/// What every [PaymentPlatformDataSource] must do, whatever runs the payment.
/// Run against the fake now; in the native milestone the same suite runs
/// against the channel-based source (a mocked binary messenger that plays a
/// foreground service), which is what makes the swap safe.
///
/// Every case runs under `fakeAsync`, so [create] is called inside it and the
/// implementation must schedule only with timers, never with real time.
/// [completionTime] is how long, in fake time, a started payment needs to reach
/// a terminal state that is not a cancel.
void paymentPlatformDataSourceContract(
  String name,
  PaymentPlatformDataSource Function() create, {
  required Duration completionTime,
}) {
  group('PaymentPlatformDataSource contract: $name', () {
    test(
      'snapshot is scoped and follows progress and every retained terminal',
      () {
        fakeAsync((async) {
          final source = create();
          PaymentProgressDto? snapshot;
          void read(String id) {
            unawaited(
              source
                  .getPaymentSnapshot(attemptId: id)
                  .then((value) => snapshot = value),
            );
            async.flushMicrotasks();
          }

          read('attempt-1');
          expect(snapshot, PaymentProgressDto.idle);
          unawaited(source.startPayment(_request));
          async.flushMicrotasks();
          read('attempt-1');
          expect(snapshot?.state, PaymentChannel.stateRunning);
          read('other-attempt');
          expect(snapshot, PaymentProgressDto.idle);
          unawaited(source.cancelPayment(attemptId: 'attempt-1'));
          async.flushMicrotasks();
          read('attempt-1');
          expect(snapshot?.state, PaymentChannel.stateCancelled);
          unawaited(source.startPayment(_request));
          async.elapse(completionTime);
          read('attempt-1');
          expect(_terminalStates, contains(snapshot?.state));
          expect(snapshot?.attemptId, 'attempt-1');
          expectNoPendingTimers(async);
        });
      },
    );

    test('a stale cancellation cannot cancel a retry of the same bill', () {
      fakeAsync((async) {
        final source = create();
        final events = _record(source);
        unawaited(source.startPayment(_request));
        async.flushMicrotasks();
        unawaited(source.cancelPayment(attemptId: 'attempt-1'));
        async.flushMicrotasks();
        unawaited(
          source.startPayment(
            const StartPaymentRequestDto(
              paymentId: 'bill-1',
              attemptId: 'attempt-2',
              amountMinor: 1100,
              currency: 'USD',
            ),
          ),
        );
        async.flushMicrotasks();
        unawaited(source.cancelPayment(attemptId: 'attempt-1'));
        async.flushMicrotasks();
        expect(events.last.state, PaymentChannel.stateRunning);
        expect(events.last.attemptId, 'attempt-2');
        unawaited(source.cancelPayment(attemptId: 'attempt-2'));
        async.flushMicrotasks();
        expect(events.last.state, PaymentChannel.stateCancelled);
        expect(events.last.attemptId, 'attempt-2');
        expectNoPendingTimers(async);
      });
    });

    test('is idle before any payment', () {
      fakeAsync((async) {
        final events = _record(create());
        async.flushMicrotasks();

        expect(events.single.state, PaymentChannel.stateIdle);
      });
    });

    test('accepts a payment and reports it running from 0', () {
      fakeAsync((async) {
        final source = create();
        final events = _record(source);

        unawaited(source.startPayment(_request));
        async.flushMicrotasks();

        expect(events.last.state, PaymentChannel.stateRunning);
        expect(events.last.paymentId, _request.paymentId);
        expect(events.last.percent, 0);
        unawaited(source.cancelPayment(attemptId: 'attempt-1'));
        async.flushMicrotasks();
        expectNoPendingTimers(async);
      });
    });

    test('percent never decreases and the run ends in one terminal state', () {
      fakeAsync((async) {
        final source = create();
        final events = _record(source);

        unawaited(source.startPayment(_request));
        async.elapse(completionTime);
        final settled = events.length;
        async.elapse(completionTime);

        expect(
          events.length,
          settled,
          reason: 'nothing may follow a terminal state',
        );
        expect(events.first.state, PaymentChannel.stateIdle);
        expect(_terminalStates, contains(events.last.state));
        expect(
          events.where((e) => _terminalStates.contains(e.state)),
          hasLength(1),
        );
        final percents = events
            .where((e) => e.state == PaymentChannel.stateRunning)
            .map((e) => e.percent!)
            .toList();
        expect(percents.first, 0);
        expect([...percents]..sort(), percents, reason: 'percent went back');
        expectNoPendingTimers(async);
      });
    });

    test(
      'rejects a second start while one runs, and the first keeps going',
      () {
        fakeAsync((async) {
          final source = create();
          final events = _record(source);
          unawaited(source.startPayment(_request));
          async.flushMicrotasks();

          final second = FutureProbe(source.startPayment(_request));
          async.flushMicrotasks();

          expect(
            second.error,
            _platformError(ChannelErrorCodes.alreadyRunning),
          );
          expect(
            events.where((e) => e.state == PaymentChannel.stateRunning),
            hasLength(1),
            reason: 'the rejected start must not restart the run',
          );
          unawaited(source.cancelPayment(attemptId: 'attempt-1'));
          async.flushMicrotasks();
          expectNoPendingTimers(async);
        });
      },
    );

    test('rejects an amount that is not positive with INVALID_ARGS', () {
      fakeAsync((async) {
        final source = create();
        final events = _record(source);

        for (final amount in [0, -5]) {
          final probe = FutureProbe(
            source.startPayment(
              StartPaymentRequestDto(
                paymentId: 'bill-1',
                amountMinor: amount,
                currency: 'USD',
                attemptId: 'attempt-1',
              ),
            ),
          );
          async.flushMicrotasks();

          expect(probe.error, _platformError(ChannelErrorCodes.invalidArgs));
        }
        expect(events.single.state, PaymentChannel.stateIdle);
        expectNoPendingTimers(async);
      });
    });

    test('cancel reports cancelled, and a new payment may start after it', () {
      fakeAsync((async) {
        final source = create();
        final events = _record(source);
        unawaited(source.startPayment(_request));
        async.flushMicrotasks();

        unawaited(source.cancelPayment(attemptId: 'attempt-1'));
        async.flushMicrotasks();
        expect(events.last.state, PaymentChannel.stateCancelled);

        unawaited(source.startPayment(_request));
        async.flushMicrotasks();
        expect(events.last.state, PaymentChannel.stateRunning);
        unawaited(source.cancelPayment(attemptId: 'attempt-1'));
        async.flushMicrotasks();
        expectNoPendingTimers(async);
      });
    });

    test('cancel with nothing running does nothing and does not throw', () {
      fakeAsync((async) {
        final source = create();
        final events = _record(source);

        final cancel = FutureProbe(
          source.cancelPayment(attemptId: 'attempt-1'),
        );
        async.flushMicrotasks();

        expect(cancel.isDone, isTrue);
        expect(cancel.error, isNull);
        expect(events.single.state, PaymentChannel.stateIdle);
      });
    });

    test(
      'replays the terminal state to a late listener until the next start',
      () {
        fakeAsync((async) {
          final source = create();
          unawaited(source.startPayment(_request));
          async.elapse(completionTime);

          final late = _record(source);
          async.flushMicrotasks();

          expect(late, hasLength(1));
          expect(_terminalStates, contains(late.single.state));
        });
      },
    );
  });
}
