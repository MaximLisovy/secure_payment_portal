import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/error/failure_mapper.dart';
import 'package:secure_payment_portal/core/logging/logger.dart';

import '../../helpers/recording_logger.dart';

void main() {
  group('Failure', () {
    test('has a stable user-safe message key per kind', () {
      expect(const NetworkFailure().messageKey, 'error.network');
      expect(const NotFoundFailure().messageKey, 'error.not_found');
      expect(const InvalidDataFailure().messageKey, 'error.invalid_data');
      expect(const PlatformFailure('X').messageKey, 'error.platform');
      expect(const UnsupportedFailure().messageKey, 'error.unsupported');
      expect(const UnexpectedFailure().messageKey, 'error.unexpected');
    });

    test('compares by value, including the platform code', () {
      expect(const PlatformFailure('A'), const PlatformFailure('A'));
      expect(const PlatformFailure('A'), isNot(const PlatformFailure('B')));
      expect(const NetworkFailure(), isNot(const NotFoundFailure()));
    });
  });

  group('failureFromError logging', () {
    test('an error with no failure of its own is logged once, by type', () {
      final logger = RecordingLogger();
      final stack = StackTrace.current;

      final failure = failureFromError(
        StateError('card 4111 1111 1111 1111'),
        logger: logger,
        stackTrace: stack,
      );

      expect(failure, const UnexpectedFailure());
      final entry = logger.errors.single;
      expect(entry.error, StateError, reason: 'the type, not the text');
      expect(entry.stackTrace, stack);
      expect(logger.entries, hasLength(1));
    });

    test('never repeats what the error said', () {
      final logger = RecordingLogger();

      failureFromError(
        Exception('token abc-123 for card 4111'),
        logger: logger,
      );

      expect(logger.entries.single.everything, isNot(contains('4111')));
      expect(logger.entries.single.everything, isNot(contains('abc-123')));
    });

    test('says so when the caller has no stack trace', () {
      final logger = RecordingLogger();

      failureFromError('not even an exception', logger: logger);

      expect(logger.errors.single.stackTrace, isNull);
      expect(logger.errors.single.error, String);
    });

    test('logs nothing for the errors that have a failure of their own', () {
      final logger = RecordingLogger();

      for (final error in <Object>[
        const NetworkException(),
        const NotFoundException(),
        const PlatformCallException('INTERNAL', 'card 4111'),
        const UnsupportedException(),
        const MalformedPayloadException('bad'),
      ]) {
        failureFromError(error, logger: logger);
      }

      expect(logger.entries, isEmpty);
    });
  });

  group('failureFromError', () {
    test('maps every data-source exception to its failure', () {
      expect(
        failureFromError(
          const NetworkException(),
          logger: const SilentLogger(),
        ),
        const NetworkFailure(),
      );
      expect(
        failureFromError(
          const NotFoundException(),
          logger: const SilentLogger(),
        ),
        const NotFoundFailure(),
      );
      expect(
        failureFromError(
          const PlatformCallException('INTERNAL'),
          logger: const SilentLogger(),
        ),
        const PlatformFailure('INTERNAL'),
      );
      expect(
        failureFromError(
          const UnsupportedException(),
          logger: const SilentLogger(),
        ),
        const UnsupportedFailure(),
      );
      expect(
        failureFromError(
          const MalformedPayloadException('bad'),
          logger: const SilentLogger(),
        ),
        const InvalidDataFailure(),
      );
    });

    test(
      'maps anything unmodelled to UnexpectedFailure instead of hiding it',
      () {
        expect(
          failureFromError(StateError('boom'), logger: const SilentLogger()),
          const UnexpectedFailure(),
        );
        expect(
          failureFromError(
            'not even an exception',
            logger: const SilentLogger(),
          ),
          const UnexpectedFailure(),
        );
      },
    );
  });
}
