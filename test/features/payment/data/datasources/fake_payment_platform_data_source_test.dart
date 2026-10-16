import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_config.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_progress_dto.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/start_payment_request_dto.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_scenario.dart';

import '../../../../helpers/fake_async_helpers.dart';
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

FakePaymentPlatformDataSource _source([FakePaymentConfig config = _config]) =>
    FakePaymentPlatformDataSource(config: config, now: () => _clock);

void main() {
  paymentPlatformDataSourceContract(
    'FakePaymentPlatformDataSource',
    _source,
    completionTime: _config.totalDuration,
  );

  group('FakePaymentPlatformDataSource script', () {
    test('runs the same script every time, step by step', () {
      fakeAsync((async) {
        final source = _source();
        final events = _record(source);

        unawaited(source.startPayment(sampleRequest));
        async.flushMicrotasks();
        expect(events, ['idle', 'running 0']);

        for (final percent in [25, 50, 75, 100]) {
          async.elapse(_step);
          expect(events.last, 'running $percent');
        }

        async.elapse(_step);
        expect(events.last, 'succeeded');
        expect(events, hasLength(7));
        expectNoPendingTimers(async);
      });
    });

    test('the receipt carries the request and the injected clock', () {
      fakeAsync((async) {
        final source = _source();
        final last = <PaymentProgressDto>[];
        source.watchProgress().listen(last.add);

        unawaited(source.startPayment(sampleRequest));
        async.elapse(_config.totalDuration);

        expect(
          last.last,
          PaymentProgressDto.succeeded(
            paymentId: 'bill-1',
            transactionId: 'FAKE-TX-000001',
            amountMinor: 1100,
            currency: 'USD',
            completedAtMillis: _clock.millisecondsSinceEpoch,
            attemptId: 'attempt-1',
          ),
        );
      });
    });

    test('numbers the transactions one after the other', () {
      fakeAsync((async) {
        final source = _source();
        final last = <PaymentProgressDto>[];
        source.watchProgress().listen(last.add);

        unawaited(source.startPayment(sampleRequest));
        async.elapse(_config.totalDuration);
        unawaited(source.startPayment(sampleRequest));
        async.elapse(_config.totalDuration);

        expect(last.last.transactionId, 'FAKE-TX-000002');
      });
    });

    final outcomes = <(String, PaymentScenario, String)>[
      (
        'a declined payment',
        PaymentScenario.declined,
        PaymentChannel.failureDeclined,
      ),
      (
        'a payment that fails while processing',
        PaymentScenario.processingFailure,
        PaymentChannel.failureProcessing,
      ),
    ];
    for (final (name, outcome, errorCode) in outcomes) {
      test('can play $name', () {
        fakeAsync((async) {
          final source = _source(
            FakePaymentConfig(stepDelay: _step, steps: 2, scenario: outcome),
          );
          final events = _record(source);

          unawaited(source.startPayment(sampleRequest));
          async.elapse(const Duration(milliseconds: 300));

          expect(events.last, 'failed $errorCode');
          expectNoPendingTimers(async);
        });
      });
    }

    test('knows how long the whole script takes', () {
      expect(_config.totalDuration, const Duration(milliseconds: 500));
    });
  });

  group('FakePaymentPlatformDataSource cancelling', () {
    test('cancel stops the script for good', () {
      fakeAsync((async) {
        final source = _source();
        final events = _record(source);
        unawaited(source.startPayment(sampleRequest));
        async.elapse(_step * 2);

        unawaited(source.cancelPayment(attemptId: 'attempt-1'));
        async.elapse(_config.totalDuration);

        expect(events, [
          'idle',
          'running 0',
          'running 25',
          'running 50',
          'cancelled',
        ]);
        expectNoPendingTimers(async);
      });
    });

    test('cancel after the payment finished leaves the result alone', () {
      fakeAsync((async) {
        final source = _source();
        final events = _record(source);
        unawaited(source.startPayment(sampleRequest));
        async.elapse(_config.totalDuration);

        unawaited(source.cancelPayment(attemptId: 'attempt-1'));
        async.flushMicrotasks();

        expect(events.last, 'succeeded');
      });
    });
  });

  group('FakePaymentPlatformDataSource rejecting', () {
    test('a rejected start changes nothing and leaves no timer behind', () {
      fakeAsync((async) {
        final source = _source();
        final events = _record(source);

        final rejected = FutureProbe(
          source.startPayment(
            const StartPaymentRequestDto(
              paymentId: 'bill-1',
              amountMinor: 0,
              currency: 'USD',
              attemptId: 'attempt-1',
            ),
          ),
        );
        async.elapse(_config.totalDuration);

        expect(rejected.error, isA<PlatformCallException>());
        expect(events, ['idle']);
        expectNoPendingTimers(async);
      });
    });

    test('a second start does not disturb the running payment', () {
      fakeAsync((async) {
        final source = _source();
        final events = _record(source);
        unawaited(source.startPayment(sampleRequest));
        async.elapse(_step);

        final second = FutureProbe(source.startPayment(sampleRequest));
        async.elapse(_step);

        expect(second.error, isA<PlatformCallException>());
        expect(events, ['idle', 'running 0', 'running 25', 'running 50']);
      });
    });
  });

  group('FakePaymentPlatformDataSource listeners', () {
    test('a listener that arrives mid-run starts from the current percent', () {
      fakeAsync((async) {
        final source = _source();
        unawaited(source.startPayment(sampleRequest));
        async.elapse(_step * 3);

        final events = _record(source);
        async.flushMicrotasks();

        expect(events, ['running 75']);
      });
    });

    test('dispose stops the script and completes the stream', () {
      fakeAsync((async) {
        final source = _source();
        final events = <String>[];
        var done = false;
        source.watchProgress().listen(
          (dto) => events.add(_describe(dto)),
          onDone: () => done = true,
        );
        unawaited(source.startPayment(sampleRequest));
        async.elapse(_step);
        final before = List<String>.of(events);

        unawaited(source.dispose());
        async.elapse(_config.totalDuration);

        expect(done, isTrue);
        expect(events, before, reason: 'nothing may be reported after dispose');
        expectNoPendingTimers(async);
      });
    });
  });

  group('as a PaymentScenarioControl', () {
    PaymentScenarioControl controlOf(FakePaymentPlatformDataSource fake) =>
        fake;

    test('starts with the scenario of its config', () {
      final fake = _source(
        const FakePaymentConfig(scenario: PaymentScenario.declined),
      );

      expect(controlOf(fake).scenario, PaymentScenario.declined);
    });

    test('a changed scenario applies to the next payment', () {
      fakeAsync((async) {
        final fake = _source();
        final events = _record(fake);

        controlOf(fake).setScenario(PaymentScenario.declined);
        unawaited(fake.startPayment(sampleRequest));
        async.elapse(_config.totalDuration);

        expect(events.last, 'failed ${PaymentChannel.failureDeclined}');
        unawaited(fake.dispose());
        expectNoPendingTimers(async);
      });
    });

    test('a payment already running keeps the script it began with', () {
      fakeAsync((async) {
        final fake = _source();
        final events = _record(fake);

        unawaited(fake.startPayment(sampleRequest));
        async.elapse(_step);
        controlOf(fake).setScenario(PaymentScenario.declined);
        async.elapse(_config.totalDuration);

        expect(events.last, 'succeeded');
        unawaited(fake.dispose());
        expectNoPendingTimers(async);
      });
    });
  });
}
