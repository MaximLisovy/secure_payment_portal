import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_progress_dto.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/start_payment_request_dto.dart';
import '../../../helpers/fake_time.dart';

const _request = StartPaymentRequestDto(
  paymentId: 'bill-1',
  amountMinor: 1100,
  currency: 'USD',
);

const _terminalStates = {
  PaymentChannel.stateSucceeded,
  PaymentChannel.stateFailed,
  PaymentChannel.stateCancelled,
};

/// What every [PaymentPlatformDataSource] must do, whatever runs the payment.
/// Run against the fake now; in the native milestone the same suite runs
/// against the channel-based source (a mocked binary messenger that plays a
/// foreground service), which is what makes the swap safe.
///
/// [completionTime] is how long, in fake time, a started payment needs to reach
/// a terminal state that is not a cancel.
void paymentPlatformDataSourceContract(
  String name,
  PaymentPlatformDataSource Function() create, {
  required Duration completionTime,
}) {
  group('PaymentPlatformDataSource contract: $name', () {
    test('is idle before any payment', () async {
      final first = await create().watchProgress().first;

      expect(first.state, PaymentChannel.stateIdle);
    });

    testWidgets('accepts a payment and reports it running from 0', (
      tester,
    ) async {
      final source = create();
      final events = <PaymentProgressDto>[];
      final subscription = source.watchProgress().listen(events.add);

      await source.startPayment(_request);
      await tester.pump();

      expect(events.last.state, PaymentChannel.stateRunning);
      expect(events.last.paymentId, _request.paymentId);
      expect(events.last.percent, 0);
      await source.cancelPayment();
      await settle(tester, subscription.cancel());
    });

    testWidgets(
      'percent never decreases and the run ends in one terminal state',
      (tester) async {
        final source = create();
        final events = <PaymentProgressDto>[];
        final subscription = source.watchProgress().listen(events.add);

        await source.startPayment(_request);
        await tester.pump(completionTime);
        final settled = events.length;
        await tester.pump(completionTime);

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
        expect(
          [...percents]..sort(),
          percents,
          reason: 'percent must not go back',
        );
        await settle(tester, subscription.cancel());
      },
    );

    test(
      'rejects a second start while one runs, and the first keeps going',
      () async {
        final source = create();
        final events = <PaymentProgressDto>[];
        final subscription = source.watchProgress().listen(events.add);
        await source.startPayment(_request);

        await expectLater(
          source.startPayment(_request),
          throwsA(
            isA<PlatformCallException>().having(
              (e) => e.code,
              'code',
              ChannelErrorCodes.alreadyRunning,
            ),
          ),
        );

        await pumpEventQueue();
        expect(
          events.where((e) => e.state == PaymentChannel.stateRunning),
          hasLength(1),
          reason: 'the rejected start must not restart the run',
        );
        await source.cancelPayment();
        await subscription.cancel();
      },
    );

    test('rejects an amount that is not positive with INVALID_ARGS', () async {
      final source = create();

      for (final amount in [0, -5]) {
        await expectLater(
          source.startPayment(
            StartPaymentRequestDto(
              paymentId: 'bill-1',
              amountMinor: amount,
              currency: 'USD',
            ),
          ),
          throwsA(
            isA<PlatformCallException>().having(
              (e) => e.code,
              'code',
              ChannelErrorCodes.invalidArgs,
            ),
          ),
        );
      }
      expect(
        (await source.watchProgress().first).state,
        PaymentChannel.stateIdle,
      );
    });

    test(
      'cancel reports cancelled, and a new payment may start after it',
      () async {
        final source = create();
        final events = <PaymentProgressDto>[];
        final subscription = source.watchProgress().listen(events.add);
        await source.startPayment(_request);

        await source.cancelPayment();
        await pumpEventQueue();
        expect(events.last.state, PaymentChannel.stateCancelled);

        await source.startPayment(_request);
        await pumpEventQueue();
        expect(events.last.state, PaymentChannel.stateRunning);
        await source.cancelPayment();
        await subscription.cancel();
      },
    );

    test(
      'cancel with nothing running does nothing and does not throw',
      () async {
        final source = create();

        await source.cancelPayment();

        expect(
          (await source.watchProgress().first).state,
          PaymentChannel.stateIdle,
        );
      },
    );

    testWidgets(
      'replays the terminal state to a late listener until the next start',
      (tester) async {
        final source = create();
        await source.startPayment(_request);
        await tester.pump(completionTime);

        final late = <PaymentProgressDto>[];
        final subscription = source.watchProgress().listen(late.add);
        await tester.pump();

        expect(late, hasLength(1));
        expect(_terminalStates, contains(late.single.state));
        await settle(tester, subscription.cancel());
      },
    );
  });
}
