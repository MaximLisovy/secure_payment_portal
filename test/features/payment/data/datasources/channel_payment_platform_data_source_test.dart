import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/core/logging/logger.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/channel_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_bills.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_progress_dto.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/start_payment_request_dto.dart';
import 'package:secure_payment_portal/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_failures.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';

import '../../../../helpers/fake_async_helpers.dart';
import '../../../../helpers/recording_logger.dart';
import '../../helpers/native_payment_simulator.dart';
import '../payment_platform_data_source_contract.dart';

const _request = StartPaymentRequestDto(
  paymentId: 'bill-1',
  amountMinor: 1100,
  currency: 'USD',
);

ChannelPaymentPlatformDataSource _source({
  Duration callTimeout = const Duration(seconds: 5),
  Logger logger = const SilentLogger(),
}) {
  final source = ChannelPaymentPlatformDataSource(
    methods: paymentMethodChannel,
    progressEvents: paymentProgressChannel,
    logger: logger,
    callTimeout: callTimeout,
  );
  addTearDown(source.dispose);
  return source;
}

NativePaymentSimulator _service() {
  final service = NativePaymentSimulator();
  addTearDown(NativePaymentSimulator.uninstall);
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The suite the fake passes, unchanged, against the channel-based source.
  paymentPlatformDataSourceContract(
    'ChannelPaymentPlatformDataSource',
    () {
      _service();
      return _source();
    },
    // The simulator's script: four steps of 100 ms, then the end one step later.
    completionTime: const Duration(milliseconds: 500),
  );

  group('ChannelPaymentPlatformDataSource', () {
    group('startPayment and the notification permission', () {
      test('asks for the permission first, then starts', () {
        fakeAsync((async) {
          final service = _service();
          final source = _source();

          unawaited(source.startPayment(_request));
          async.flushMicrotasks();

          expect(service.calls, [
            PaymentChannel.requestNotificationPermission,
            PaymentChannel.startPayment,
          ]);
          unawaited(source.cancelPayment());
          async.flushMicrotasks();
          expectNoPendingTimers(async);
        });
      });

      for (final answer in [
        NotificationPermissionWire.granted,
        NotificationPermissionWire.denied,
        NotificationPermissionWire.notRequired,
      ]) {
        test('the payment starts when the answer is $answer', () {
          fakeAsync((async) {
            final service = _service()..permissionAnswer = answer;
            final source = _source();
            final events = <PaymentProgressDto>[];
            source.watchProgress().listen(events.add);

            final start = FutureProbe(source.startPayment(_request));
            async.flushMicrotasks();

            expect(start.isDone && start.error == null, isTrue);
            expect(events.last.state, PaymentChannel.stateRunning);
            expect(service.calls, contains(PaymentChannel.startPayment));
            unawaited(source.cancelPayment());
            async.flushMicrotasks();
          });
        });
      }

      test('a permission call that fails does not stop the payment', () {
        fakeAsync((async) {
          final service = _service()..permissionFails = true;
          final source = _source();

          final start = FutureProbe(source.startPayment(_request));
          async.flushMicrotasks();

          expect(start.isDone && start.error == null, isTrue);
          expect(service.calls, contains(PaymentChannel.startPayment));
          unawaited(source.cancelPayment());
          async.flushMicrotasks();
        });
      });

      // The prompt takes as long as the user does; only startPayment is timed.
      test('a long permission prompt is not cut off by the call timeout', () {
        fakeAsync((async) {
          final service = _service()
            ..permissionDelay = const Duration(seconds: 40);
          final source = _source(callTimeout: const Duration(seconds: 5));

          final start = FutureProbe(source.startPayment(_request));
          async.elapse(const Duration(seconds: 39));
          expect(start.isDone, isFalse, reason: 'still waiting for the user');

          async.elapse(const Duration(seconds: 2));
          expect(start.isDone && start.error == null, isTrue);
          expect(service.calls.last, PaymentChannel.startPayment);
          unawaited(source.cancelPayment());
          async.flushMicrotasks();
        });
      });

      test('no native side at all is unsupported, not a crash', () async {
        // No simulator: nothing answers on either channel.
        await expectLater(
          _source().startPayment(_request),
          throwsA(isA<UnsupportedException>()),
        );
      });
    });

    group('error replies', () {
      for (final code in [
        ChannelErrorCodes.alreadyRunning,
        ChannelErrorCodes.startNotAllowed,
        ChannelErrorCodes.invalidArgs,
        ChannelErrorCodes.internal,
      ]) {
        test('$code keeps its code', () {
          fakeAsync((async) {
            _service().startFailsWith = code;
            final start = FutureProbe(_source().startPayment(_request));
            async.flushMicrotasks();

            expect(
              start.error,
              isA<PlatformCallException>().having((e) => e.code, 'code', code),
            );
          });
        });
      }
    });

    group('what it logs', () {
      test('says nothing when everything works', () {
        fakeAsync((async) {
          final logger = RecordingLogger();
          final service = _service();
          final source = _source(logger: logger);

          unawaited(source.startPayment(_request));
          async.elapse(service.completionTime);
          source.watchProgress().listen((_) {});
          async.flushMicrotasks();

          expect(logger.entries, isEmpty);
        });
      });

      test('an error reply is a warning with the method and the code only', () {
        fakeAsync((async) {
          final logger = RecordingLogger();
          _service().startFailsWith = ChannelErrorCodes.startNotAllowed;
          final source = _source(logger: logger);

          unawaited(
            source
                .startPayment(_request)
                .then<void>((_) {}, onError: (Object _) {}),
          );
          async.flushMicrotasks();

          final warning = logger.warnings.single;
          expect(warning.message, contains(PaymentChannel.startPayment));
          expect(warning.message, contains(ChannelErrorCodes.startNotAllowed));
          expect(logger.entries.single.everything, isNot(contains('4111')));
          expect(
            logger.entries.single.everything,
            isNot(contains('bill-1')),
            reason: 'nor the arguments of the call',
          );
        });
      });

      test(
        'a failed permission request is logged and the payment still starts',
        () {
          fakeAsync((async) {
            final logger = RecordingLogger();
            final service = _service()..permissionFails = true;
            final source = _source(logger: logger);

            final start = FutureProbe(source.startPayment(_request));
            async.flushMicrotasks();

            expect(start.isDone && start.error == null, isTrue);
            expect(service.calls, contains(PaymentChannel.startPayment));
            expect(
              logger.warnings.single.message,
              contains('notification permission'),
            );
            expect(logger.entries.single.everything, isNot(contains('4111')));
            unawaited(source.cancelPayment());
            async.flushMicrotasks();
          });
        },
      );

      test('a start that is never answered is a warning', () {
        fakeAsync((async) {
          final logger = RecordingLogger();
          _service().hangOnStart = true;
          final source = _source(
            callTimeout: const Duration(seconds: 3),
            logger: logger,
          );
          unawaited(
            source
                .startPayment(_request)
                .then<void>((_) {}, onError: (Object _) {}),
          );

          async.elapse(const Duration(seconds: 4));

          expect(
            logger.warnings.single.message,
            contains('did not answer in time'),
          );
        });
      });

      test('no native side is expected, so it is not logged', () async {
        final logger = RecordingLogger();
        final source = _source(logger: logger);

        await expectLater(
          source.startPayment(_request),
          throwsA(isA<UnsupportedException>()),
        );

        expect(logger.entries, isEmpty);
      });

      test('a malformed event is a warning without its content', () {
        fakeAsync((async) {
          final logger = RecordingLogger();
          final service = _service();
          final source = _source(logger: logger);
          source.watchProgress().listen((_) {}, onError: (Object _) {});
          async.flushMicrotasks();

          service.sendRaw('card 4111 1111 1111 1111');
          async.flushMicrotasks();

          expect(logger.warnings.single.message, contains('malformed'));
          expect(logger.entries.single.everything, isNot(contains('4111')));
        });
      });

      test('an error event is a warning with its code, not its message', () {
        fakeAsync((async) {
          final logger = RecordingLogger();
          final service = _service();
          final source = _source(logger: logger);
          source.watchProgress().listen((_) {}, onError: (Object _) {});
          async.flushMicrotasks();

          service.sendError();
          async.flushMicrotasks();

          expect(logger.warnings.single.message, contains('BOOM'));
          expect(logger.entries.single.everything, isNot(contains('4111')));
        });
      });
    });

    group('a start that is never answered', () {
      test('fails as unavailable once the timeout passes', () {
        fakeAsync((async) {
          _service().hangOnStart = true;
          final source = _source(callTimeout: const Duration(seconds: 3));
          final start = FutureProbe(source.startPayment(_request));

          async.elapse(const Duration(seconds: 2));
          expect(start.isDone, isFalse, reason: 'it may still answer');

          async.elapse(const Duration(seconds: 2));
          expect(
            start.error,
            isA<PlatformCallException>().having(
              (e) => e.code,
              'code',
              ChannelErrorCodes.unavailable,
            ),
          );
          expectNoPendingTimers(async);
        });
      });
    });

    group('watchProgress', () {
      test('replays idle first, then follows a payment to its end', () {
        fakeAsync((async) {
          final service = _service();
          final source = _source();
          final seen = <String>[];
          source.watchProgress().listen((dto) => seen.add(dto.state));
          async.flushMicrotasks();

          unawaited(source.startPayment(_request));
          async.elapse(service.completionTime);

          expect(seen.first, PaymentChannel.stateIdle);
          expect(seen.last, PaymentChannel.stateSucceeded);
          expect(
            seen.where((s) => s == PaymentChannel.stateSucceeded),
            hasLength(1),
          );
          expectNoPendingTimers(async);
        });
      });

      test('shares one native listener between any number of listeners', () {
        fakeAsync((async) {
          final service = _service();
          final source = _source();
          final a = <String>[];
          final b = <String>[];
          final c = <String>[];

          final first = source.watchProgress().listen(
            (dto) => a.add(dto.state),
          );
          async.flushMicrotasks();
          unawaited(source.startPayment(_request));
          async.flushMicrotasks();
          final second = source.watchProgress().listen(
            (dto) => b.add(dto.state),
          );
          final third = source.watchProgress().listen(
            (dto) => c.add(dto.state),
          );
          async.flushMicrotasks();

          expect(service.listens, 1, reason: 'a second listen would replace');
          expect(b, [PaymentChannel.stateRunning]);
          expect(c, [PaymentChannel.stateRunning]);

          unawaited(first.cancel());
          unawaited(second.cancel());
          async.flushMicrotasks();
          expect(service.cancels, 0, reason: 'one listener is still there');

          unawaited(third.cancel());
          async.flushMicrotasks();
          expect(service.cancels, 1);

          unawaited(source.cancelPayment());
          async.flushMicrotasks();
          expectNoPendingTimers(async);
        });
      });

      test('reopens without a stale replay, and a terminal state stays', () {
        fakeAsync((async) {
          final service = _service();
          final source = _source();
          final seen = <String>[];
          var listener = source.watchProgress().listen(
            (dto) => seen.add(dto.state),
          );
          async.flushMicrotasks();
          unawaited(source.startPayment(_request));
          async.elapse(service.completionTime);
          unawaited(listener.cancel());
          async.flushMicrotasks();
          seen.clear();

          // Everyone left; a new listener is replayed what the service says
          // now (the sticky terminal state), nothing remembered from before.
          listener = source.watchProgress().listen(
            (dto) => seen.add(dto.state),
          );
          async.flushMicrotasks();

          expect(seen, [PaymentChannel.stateSucceeded]);
          expect(service.listens, 2);
          unawaited(listener.cancel());
          async.flushMicrotasks();
        });
      });

      test('an event outside the documented shape is a typed error', () {
        fakeAsync((async) {
          final service = _service();
          final source = _source();
          final seen = <String>[];
          final errors = <Object>[];
          source.watchProgress().listen(
            (dto) => seen.add(dto.state),
            onError: errors.add,
          );
          async.flushMicrotasks();

          service.sendRaw('garbage');
          service.sendRaw({'schemaVersion': 1, 'state': 'running'});
          service.sendRaw({'schemaVersion': 1, 'state': 'on fire'});
          service.sendRaw(const PaymentProgressDto.running('a', 5).toMap());
          async.flushMicrotasks();

          expect(errors, everyElement(isA<MalformedPayloadException>()));
          expect(errors, hasLength(3));
          expect(seen, [PaymentChannel.stateIdle, PaymentChannel.stateRunning]);
        });
      });

      test('an error event is a typed error and the stream carries on', () {
        fakeAsync((async) {
          final service = _service();
          final source = _source();
          final seen = <String>[];
          final errors = <Object>[];
          source.watchProgress().listen(
            (dto) => seen.add(dto.state),
            onError: errors.add,
          );
          async.flushMicrotasks();

          service.sendError();
          service.sendRaw(PaymentProgressDto.cancelled.toMap());
          async.flushMicrotasks();

          expect(
            errors.single,
            isA<PlatformCallException>().having((e) => e.code, 'code', 'BOOM'),
          );
          expect(seen.last, PaymentChannel.stateCancelled);
        });
      });

      // Flutter's EventChannel does not fail the stream when `listen` fails: it
      // reports the error through FlutterError and the stream stays silent.
      test(
        'with no native side the stream stays silent instead of failing',
        () async {
          final source = _source();
          final reported = <Object>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) => reported.add(details.exception);
          addTearDown(() => FlutterError.onError = previous);
          final seen = <Object>[];
          final errors = <Object>[];

          final subscription = source.watchProgress().listen(
            seen.add,
            onError: errors.add,
          );
          await pumpEventQueue();

          expect(seen, isEmpty);
          expect(errors, isEmpty);
          expect(reported.single, isA<MissingPluginException>());
          await subscription.cancel();
        },
      );

      test(
        'disposing ends the stream and closes the native listener',
        () async {
          final service = _service();
          final source = ChannelPaymentPlatformDataSource(
            methods: paymentMethodChannel,
            progressEvents: paymentProgressChannel,
            logger: const SilentLogger(),
          );
          var done = false;
          source.watchProgress().listen((_) {}, onDone: () => done = true);
          await pumpEventQueue();

          await source.dispose();
          await pumpEventQueue();

          expect(done, isTrue);
          expect(service.cancels, 1);
          expect(service.hasListener, isFalse);
        },
      );
    });

    group('behind the repository', () {
      PaymentRepositoryImpl repositoryOn(
        ChannelPaymentPlatformDataSource source,
      ) => PaymentRepositoryImpl(
        remote: FakePaymentRemoteDataSource(),
        platform: source,
        logger: const SilentLogger(),
      );

      test('a second start is a payment already in progress', () {
        fakeAsync((async) {
          _service();
          final repository = repositoryOn(_source());
          const details = FakeBills.retailOrder;
          Result<void>? second;

          unawaited(
            repository.getPaymentDetails(details.id).then((loaded) async {
              final bill = loaded.valueOrNull!;
              await repository.startPayment(bill);
              second = await repository.startPayment(bill);
            }),
          );
          async.elapse(const Duration(milliseconds: 50));

          expect(
            second,
            isA<Err<void>>().having(
              (e) => e.failure,
              'failure',
              isA<PaymentInProgressFailure>(),
            ),
          );
          unawaited(repository.cancelPayment());
          async.flushMicrotasks();
        });
      });

      test('an unreadable event becomes a failed payment', () {
        fakeAsync((async) {
          final service = _service();
          final repository = repositoryOn(_source());
          final seen = <PaymentProgress>[];
          repository.watchProgress().listen(seen.add);
          async.flushMicrotasks();

          service.sendRaw('garbage');
          async.flushMicrotasks();

          expect(seen.first, const PaymentIdle());
          expect(seen.last, isA<PaymentFailed>());
          expect(
            (seen.last as PaymentFailed).failure,
            isA<InvalidDataFailure>(),
          );
        });
      });
    });
  });
}
