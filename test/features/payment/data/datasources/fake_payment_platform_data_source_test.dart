import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_config.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_progress_dto.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/start_payment_request_dto.dart';

import '../../../../helpers/fake_time.dart';
import '../../helpers/payment_fixtures.dart';
import '../payment_platform_data_source_contract.dart';

const _step = Duration(milliseconds: 100);
const _config = FakePaymentConfig(stepDelay: _step, steps: 4);
final _clock = DateTime.utc(2026, 10, 15, 12);

String _describe(PaymentProgressDto dto) => switch (dto.state) {
  PaymentChannel.stateRunning => 'running ${dto.percent}',
  PaymentChannel.stateFailed => 'failed ${dto.errorCode}',
  final other => other,
};

/// Collects what [source] reports, as short strings.
List<String> _record(FakePaymentPlatformDataSource source) {
  final events = <String>[];
  source.watchProgress().listen((dto) => events.add(_describe(dto)));
  return events;
}

void main() {
  paymentPlatformDataSourceContract(
    'FakePaymentPlatformDataSource',
    () => FakePaymentPlatformDataSource(config: _config, now: () => _clock),
    completionTime: _config.totalDuration,
  );

  group('FakePaymentPlatformDataSource script', () {
    testWidgets('runs the same script every time, step by step', (
      tester,
    ) async {
      final source = FakePaymentPlatformDataSource(
        config: _config,
        now: () => _clock,
      );
      final events = _record(source);

      await source.startPayment(sampleRequest);
      await tester.pump();
      expect(events, ['idle', 'running 0']);

      for (final percent in [25, 50, 75, 100]) {
        await tester.pump(_step);
        expect(events.last, 'running $percent');
      }

      await tester.pump(_step);
      expect(events.last, 'succeeded');
      expect(events, hasLength(7));
      await settle(tester, source.dispose());
    });

    testWidgets('the receipt carries the request and the injected clock', (
      tester,
    ) async {
      final source = FakePaymentPlatformDataSource(
        config: _config,
        now: () => _clock,
      );
      final last = <PaymentProgressDto>[];
      source.watchProgress().listen(last.add);

      await source.startPayment(sampleRequest);
      await tester.pump(_config.totalDuration);

      expect(
        last.last,
        PaymentProgressDto.succeeded(
          paymentId: 'bill-1',
          transactionId: 'FAKE-TX-000001',
          amountMinor: 1100,
          currency: 'USD',
          completedAtMillis: _clock.millisecondsSinceEpoch,
        ),
      );
      await settle(tester, source.dispose());
    });

    testWidgets('numbers the transactions one after the other', (tester) async {
      final source = FakePaymentPlatformDataSource(
        config: _config,
        now: () => _clock,
      );
      final last = <PaymentProgressDto>[];
      source.watchProgress().listen(last.add);

      await source.startPayment(sampleRequest);
      await tester.pump(_config.totalDuration);
      await source.startPayment(sampleRequest);
      await tester.pump(_config.totalDuration);

      expect(last.last.transactionId, 'FAKE-TX-000002');
      await settle(tester, source.dispose());
    });

    testWidgets('can play a declined payment', (tester) async {
      final source = FakePaymentPlatformDataSource(
        config: const FakePaymentConfig(
          stepDelay: _step,
          steps: 2,
          outcome: FakePaymentOutcome.declined,
        ),
      );
      final events = _record(source);

      await source.startPayment(sampleRequest);
      await tester.pump(const Duration(milliseconds: 300));

      expect(events.last, 'failed ${PaymentChannel.failureDeclined}');
      await settle(tester, source.dispose());
    });

    testWidgets('can play a payment that fails while processing', (
      tester,
    ) async {
      final source = FakePaymentPlatformDataSource(
        config: const FakePaymentConfig(
          stepDelay: _step,
          steps: 2,
          outcome: FakePaymentOutcome.processingFailure,
        ),
      );
      final events = _record(source);

      await source.startPayment(sampleRequest);
      await tester.pump(const Duration(milliseconds: 300));

      expect(events.last, 'failed ${PaymentChannel.failureProcessing}');
      await settle(tester, source.dispose());
    });

    test('knows how long the whole script takes', () {
      expect(_config.totalDuration, const Duration(milliseconds: 500));
    });
  });

  group('FakePaymentPlatformDataSource cancelling', () {
    testWidgets('cancel stops the script for good', (tester) async {
      final source = FakePaymentPlatformDataSource(config: _config);
      final events = _record(source);
      await source.startPayment(sampleRequest);
      await tester.pump(_step * 2);

      await source.cancelPayment();
      await tester.pump(_config.totalDuration);

      expect(events, [
        'idle',
        'running 0',
        'running 25',
        'running 50',
        'cancelled',
      ]);
      await settle(tester, source.dispose());
    });

    testWidgets('cancel after the payment finished leaves the result alone', (
      tester,
    ) async {
      final source = FakePaymentPlatformDataSource(config: _config);
      final events = _record(source);
      await source.startPayment(sampleRequest);
      await tester.pump(_config.totalDuration);

      await source.cancelPayment();
      await tester.pump();

      expect(events.last, 'succeeded');
      await settle(tester, source.dispose());
    });
  });

  group('FakePaymentPlatformDataSource rejecting', () {
    testWidgets('a rejected start changes nothing and leaves no timer behind', (
      tester,
    ) async {
      final source = FakePaymentPlatformDataSource(config: _config);
      final events = _record(source);

      await expectLater(
        source.startPayment(
          const StartPaymentRequestDto(
            paymentId: 'bill-1',
            amountMinor: 0,
            currency: 'USD',
          ),
        ),
        throwsA(isA<PlatformCallException>()),
      );
      await tester.pump(_config.totalDuration);

      expect(events, ['idle']);
    });

    testWidgets('a second start does not disturb the running payment', (
      tester,
    ) async {
      final source = FakePaymentPlatformDataSource(config: _config);
      final events = _record(source);
      await source.startPayment(sampleRequest);
      await tester.pump(_step);

      await expectLater(
        source.startPayment(sampleRequest),
        throwsA(isA<PlatformCallException>()),
      );
      await tester.pump(_step);

      expect(events, ['idle', 'running 0', 'running 25', 'running 50']);
      await settle(tester, source.dispose());
    });
  });

  group('FakePaymentPlatformDataSource listeners', () {
    testWidgets(
      'a listener that arrives mid-run starts from the current percent',
      (tester) async {
        final source = FakePaymentPlatformDataSource(config: _config);
        await source.startPayment(sampleRequest);
        await tester.pump(_step * 3);

        final events = _record(source);
        await tester.pump();

        expect(events, ['running 75']);
        await settle(tester, source.dispose());
      },
    );

    testWidgets('dispose stops the script: nothing more is reported', (
      tester,
    ) async {
      final source = FakePaymentPlatformDataSource(config: _config);
      final events = _record(source);
      await source.startPayment(sampleRequest);
      await tester.pump(_step);
      final before = List<String>.of(events);

      await settle(tester, source.dispose());
      await tester.pump(_config.totalDuration);

      // A timer left running would also fail this test as "still pending".
      expect(events, before);
    });

    // A plain test: a Stream.multi done event is not delivered under a widget
    // test's fake clock, while it is in real time.
    test('dispose completes the stream', () async {
      final source = FakePaymentPlatformDataSource(config: _config);
      var done = false;
      final subscription = source.watchProgress().listen(
        (_) {},
        onDone: () => done = true,
      );

      await source.dispose();
      await pumpEventQueue();

      expect(done, isTrue);
      await subscription.cancel();
    });
  });
}
