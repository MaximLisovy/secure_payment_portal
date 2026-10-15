import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/error/result.dart';

void main() {
  group('Result', () {
    const success = Success<int>(21);
    const err = Err<int>(NetworkFailure());

    test('Success and Err compare by value', () {
      expect(const Success<int>(1), const Success<int>(1));
      expect(const Success<int>(1), isNot(const Success<int>(2)));
      expect(
        const Err<int>(NetworkFailure()),
        const Err<int>(NetworkFailure()),
      );
      expect(
        const Err<int>(NetworkFailure()),
        isNot(const Err<int>(NotFoundFailure())),
      );
    });

    test('Success.unit is a success with nothing to return', () {
      expect(Success.unit.isSuccess, isTrue);
    });

    test('fold runs the branch that matches', () {
      expect(
        success.fold((v) => 'ok $v', (f) => 'err ${f.messageKey}'),
        'ok 21',
      );
      expect(
        err.fold((v) => 'ok $v', (f) => 'err ${f.messageKey}'),
        'err error.network',
      );
    });

    test('map transforms a success and passes an error through', () {
      expect(success.map((v) => v * 2), const Success<int>(42));
      expect(err.map((v) => v * 2), const Err<int>(NetworkFailure()));
    });

    test('valueOrNull, failureOrNull and isSuccess agree with the case', () {
      expect(success.valueOrNull, 21);
      expect(success.failureOrNull, isNull);
      expect(success.isSuccess, isTrue);
      expect(err.valueOrNull, isNull);
      expect(err.failureOrNull, const NetworkFailure());
      expect(err.isSuccess, isFalse);
    });

    test('a switch over Result is exhaustive', () {
      String describe(Result<int> result) => switch (result) {
        Success<int>(:final value) => 'success $value',
        Err<int>(:final failure) => 'err ${failure.messageKey}',
      };

      expect(describe(success), 'success 21');
      expect(describe(err), 'err error.network');
    });
  });
}
