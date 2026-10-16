import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/core/logging/logger.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_bills.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_details_dto.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_progress_dto.dart';
import 'package:secure_payment_portal/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_failures.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';

import '../../../../helpers/recording_logger.dart';
import '../../helpers/payment_fixtures.dart';

class _MockRemote extends Mock implements PaymentRemoteDataSource {}

class _MockPlatform extends Mock implements PaymentPlatformDataSource {}

void main() {
  late _MockRemote remote;
  late _MockPlatform platform;
  late PaymentRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(sampleRequest));

  setUp(() {
    remote = _MockRemote();
    platform = _MockPlatform();
    repository = PaymentRepositoryImpl(
      remote: remote,
      platform: platform,
      logger: const SilentLogger(),
    );
  });

  group('getPaymentDetails', () {
    test('maps the bill DTO to details', () async {
      when(
        () => remote.fetchPaymentDetails('retail-order-1042'),
      ).thenAnswer((_) async => FakeBills.retailOrder);

      final result = await repository.getPaymentDetails('retail-order-1042');

      final details = result.valueOrNull;
      expect(details?.id, 'retail-order-1042');
      expect(details?.total, const Money.minor(10939, Currency.usd));
      expect(details?.lineItems.last.kind, LineItemKind.tax);
    });

    final failures = <(String, DataSourceException, Failure)>[
      ('network', const NetworkException(), const NetworkFailure()),
      ('not found', const NotFoundException(), const NotFoundFailure()),
      (
        'malformed payload',
        const MalformedPayloadException('x'),
        const InvalidDataFailure(),
      ),
    ];
    for (final (name, thrown, expected) in failures) {
      test('maps a $name exception to $expected', () async {
        when(() => remote.fetchPaymentDetails(any())).thenThrow(thrown);

        expect(
          await repository.getPaymentDetails('x'),
          Err<PaymentDetails>(expected),
        );
      });
    }

    test('a bill in an unknown currency becomes InvalidDataFailure', () async {
      when(() => remote.fetchPaymentDetails(any())).thenAnswer(
        (_) async => const PaymentDetailsDto(
          id: 'x',
          merchantName: 'm',
          reference: 'r',
          currency: 'XXX',
          lineItems: [],
        ),
      );

      expect(
        await repository.getPaymentDetails('x'),
        const Err<PaymentDetails>(InvalidDataFailure()),
      );
    });

    test('does not swallow a programming error', () async {
      when(
        () => remote.fetchPaymentDetails(any()),
      ).thenThrow(StateError('bug'));

      await expectLater(repository.getPaymentDetails('x'), throwsStateError);
    });
  });

  group('startPayment', () {
    test('sends the request built from the details', () async {
      when(() => platform.startPayment(sampleRequest)).thenAnswer((_) async {});

      final result = await repository.startPayment(
        sampleDetails,
        attemptId: 'attempt-1',
      );

      expect(result, Success.unit);
      verify(() => platform.startPayment(sampleRequest)).called(1);
    });

    final failures = <(String, DataSourceException, Failure)>[
      (
        'ALREADY_RUNNING',
        const PlatformCallException(ChannelErrorCodes.alreadyRunning),
        const PaymentInProgressFailure(),
      ),
      (
        'INVALID_ARGS',
        const PlatformCallException(ChannelErrorCodes.invalidArgs),
        const InvalidPaymentFailure(),
      ),
      (
        'START_NOT_ALLOWED',
        const PlatformCallException(ChannelErrorCodes.startNotAllowed),
        const PaymentStartNotAllowedFailure(),
      ),
      (
        'an unsupported platform',
        const UnsupportedException(),
        const UnsupportedFailure(),
      ),
      ('a network error', const NetworkException(), const NetworkFailure()),
    ];
    for (final (name, thrown, expected) in failures) {
      test('maps $name to $expected', () async {
        when(() => platform.startPayment(any())).thenThrow(thrown);

        expect(
          await repository.startPayment(sampleDetails, attemptId: 'attempt-1'),
          Err<void>(expected),
        );
      });
    }
  });

  group('cancelPayment', () {
    test('cancels on the platform', () async {
      when(
        () => platform.cancelPayment(attemptId: 'attempt-1'),
      ).thenAnswer((_) async {});

      expect(
        await repository.cancelPayment(attemptId: 'attempt-1'),
        Success.unit,
      );
      verify(() => platform.cancelPayment(attemptId: 'attempt-1')).called(1);
    });

    test('maps a platform error to a failure', () async {
      when(
        () => platform.cancelPayment(attemptId: 'attempt-1'),
      ).thenThrow(const PlatformCallException(ChannelErrorCodes.internal));

      expect(
        await repository.cancelPayment(attemptId: 'attempt-1'),
        const Err<void>(PlatformFailure(ChannelErrorCodes.internal)),
      );
    });
  });

  group('an error that no failure covers', () {
    test(
      'ends the run as UnexpectedFailure and is logged by type and stack',
      () async {
        final logger = RecordingLogger();
        final source = StreamController<PaymentProgressDto>();
        addTearDown(source.close);
        when(() => platform.watchProgress()).thenAnswer((_) => source.stream);
        final repository = PaymentRepositoryImpl(
          remote: remote,
          platform: platform,
          logger: logger,
        );
        final seen = <PaymentProgress>[];
        final subscription = repository.watchProgress().listen(seen.add);
        addTearDown(subscription.cancel);

        source.addError(StateError('card 4111 1111 1111 1111'));
        await pumpEventQueue();

        expect(seen.single, const PaymentFailed(UnexpectedFailure()));
        final entry = logger.errors.single;
        expect(entry.error, StateError);
        expect(entry.stackTrace, isNotNull);
        expect(entry.everything, isNot(contains('4111')));
      },
    );

    test('a failure of its own is not logged', () async {
      final logger = RecordingLogger();
      final repository = PaymentRepositoryImpl(
        remote: remote,
        platform: platform,
        logger: logger,
      );
      when(
        () => remote.fetchPaymentDetails(any()),
      ).thenThrow(const NetworkException());

      final result = await repository.getPaymentDetails('bill-1');

      expect(result, const Err<PaymentDetails>(NetworkFailure()));
      expect(logger.entries, isEmpty);
    });
  });

  group('watchProgress', () {
    late StreamController<PaymentProgressDto> source;
    late List<PaymentProgress> emitted;
    late bool done;
    StreamSubscription<PaymentProgress>? subscription;

    setUp(() {
      source = StreamController<PaymentProgressDto>();
      emitted = [];
      done = false;
      when(() => platform.watchProgress()).thenAnswer((_) => source.stream);
      subscription = repository.watchProgress().listen(
        emitted.add,
        onDone: () => done = true,
      );
    });

    tearDown(() async {
      await subscription?.cancel();
      await source.close();
    });

    Future<void> send(PaymentProgressDto dto) async {
      source.add(dto);
      await pumpEventQueue();
    }

    test('maps every state of the run in order', () async {
      await send(PaymentProgressDto.idle);
      await send(
        const PaymentProgressDto.running('bill-1', 0, attemptId: 'attempt-1'),
      );
      await send(
        const PaymentProgressDto.running('bill-1', 60, attemptId: 'attempt-1'),
      );
      await send(
        const PaymentProgressDto.succeeded(
          paymentId: 'bill-1',
          transactionId: 'tx-1',
          amountMinor: 1100,
          currency: 'USD',
          completedAtMillis: 1760529600000,
          attemptId: 'attempt-1',
        ),
      );

      expect(emitted.map((p) => p.runtimeType), [
        PaymentIdle,
        PaymentInProgress,
        PaymentInProgress,
        PaymentSucceeded,
      ]);
      expect(
        emitted[2],
        const PaymentInProgress('bill-1', 60, attemptId: 'attempt-1'),
      );
    });

    test('maps a decline and a cancel', () async {
      await send(
        const PaymentProgressDto.failed(
          PaymentChannel.failureDeclined,
          paymentId: 'bill-1',
          attemptId: 'attempt-1',
        ),
      );
      await send(
        const PaymentProgressDto.cancelled(
          paymentId: 'bill-1',
          attemptId: 'attempt-1',
        ),
      );

      expect(emitted, [
        const PaymentFailed(
          PaymentDeclinedFailure(),
          paymentId: 'bill-1',
          attemptId: 'attempt-1',
        ),
        const PaymentCancelled(paymentId: 'bill-1', attemptId: 'attempt-1'),
      ]);
    });

    test('drops a state identical to the previous one', () async {
      await send(
        const PaymentProgressDto.running('bill-1', 40, attemptId: 'attempt-1'),
      );
      await send(
        const PaymentProgressDto.running('bill-1', 40, attemptId: 'attempt-1'),
      );
      await send(
        const PaymentProgressDto.running('bill-1', 50, attemptId: 'attempt-1'),
      );

      expect(emitted, [
        const PaymentInProgress('bill-1', 40, attemptId: 'attempt-1'),
        const PaymentInProgress('bill-1', 50, attemptId: 'attempt-1'),
      ]);
    });

    test(
      'an event that makes no sense becomes a failure, not an error',
      () async {
        await send(
          const PaymentProgressDto.running(
            'bill-1',
            150,
            attemptId: 'attempt-1',
          ),
        );

        expect(emitted, [const PaymentFailed(InvalidDataFailure())]);
      },
    );

    test(
      'an error from the platform becomes a failure, not an error',
      () async {
        source.addError(
          const PlatformCallException(ChannelErrorCodes.internal),
        );
        await pumpEventQueue();
        source.addError(const UnsupportedException());
        await pumpEventQueue();

        expect(emitted, [
          const PaymentFailed(PlatformFailure(ChannelErrorCodes.internal)),
          const PaymentFailed(UnsupportedFailure()),
        ]);
      },
    );

    test('an error nobody modelled is still reported, not hidden', () async {
      source.addError(StateError('bug'));
      await pumpEventQueue();

      expect(emitted, [const PaymentFailed(UnexpectedFailure())]);
    });

    test('stops listening to the platform when cancelled', () async {
      expect(source.hasListener, isTrue);

      await subscription?.cancel();

      expect(source.hasListener, isFalse);
    });

    test('completes when the platform stream completes', () async {
      await source.close();
      await pumpEventQueue();

      expect(done, isTrue);
    });
  });
}
