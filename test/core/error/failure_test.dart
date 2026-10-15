import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/error/failure_mapper.dart';

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

  group('failureFromError', () {
    test('maps every data-source exception to its failure', () {
      expect(
        failureFromError(const NetworkException()),
        const NetworkFailure(),
      );
      expect(
        failureFromError(const NotFoundException()),
        const NotFoundFailure(),
      );
      expect(
        failureFromError(const PlatformCallException('INTERNAL')),
        const PlatformFailure('INTERNAL'),
      );
      expect(
        failureFromError(const UnsupportedException()),
        const UnsupportedFailure(),
      );
      expect(
        failureFromError(const MalformedPayloadException('bad')),
        const InvalidDataFailure(),
      );
    });

    test(
      'maps anything unmodelled to UnexpectedFailure instead of hiding it',
      () {
        expect(failureFromError(StateError('boom')), const UnexpectedFailure());
        expect(
          failureFromError('not even an exception'),
          const UnexpectedFailure(),
        );
      },
    );
  });
}
