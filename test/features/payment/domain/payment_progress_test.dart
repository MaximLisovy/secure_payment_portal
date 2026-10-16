import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_failures.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_result.dart';

final _result = PaymentResult(
  paymentId: 'bill-1',
  transactionId: 'tx-1',
  amount: const Money.minor(1100, Currency.usd),
  completedAt: DateTime.utc(2026, 10, 15, 12),
);

void main() {
  group('PaymentProgress', () {
    test('states compare by value, so a stream can drop repeats', () {
      expect(
        const PaymentInProgress('a', 40),
        const PaymentInProgress('a', 40),
      );
      expect(
        const PaymentInProgress('a', 40),
        isNot(const PaymentInProgress('a', 50)),
      );
      expect(
        const PaymentInProgress('a', 40),
        isNot(const PaymentInProgress('b', 40)),
      );
      expect(const PaymentIdle(), const PaymentIdle());
      expect(const PaymentCancelled(), const PaymentCancelled());
      expect(PaymentSucceeded(_result), PaymentSucceeded(_result));
      expect(
        const PaymentFailed(PaymentDeclinedFailure()),
        const PaymentFailed(PaymentDeclinedFailure()),
      );
      expect(
        const PaymentFailed(PaymentDeclinedFailure()),
        isNot(const PaymentFailed(NetworkFailure())),
      );
    });

    test('the fraction is the percent as a number between 0 and 1', () {
      expect(const PaymentInProgress('a', 0).fraction, 0);
      expect(const PaymentInProgress('a', 25).fraction, 0.25);
      expect(const PaymentInProgress('a', 100).fraction, 1);
    });

    test('a percent outside 0..100 is rejected', () {
      expect(() => PaymentInProgress('a', -1), throwsA(isA<AssertionError>()));
      expect(() => PaymentInProgress('a', 101), throwsA(isA<AssertionError>()));
    });

    test('a switch over it is exhaustive', () {
      String name(PaymentProgress progress) => switch (progress) {
        PaymentIdle() => 'idle',
        PaymentInProgress(:final percent) => 'running $percent',
        PaymentSucceeded() => 'succeeded',
        PaymentFailed(:final failure) => 'failed ${failure.messageKey}',
        PaymentCancelled() => 'cancelled',
      };

      expect(name(const PaymentInProgress('a', 10)), 'running 10');
      expect(
        name(const PaymentFailed(PaymentDeclinedFailure())),
        'failed payment.declined',
      );
    });
  });

  group('PaymentFailure', () {
    test('has a stable message key per kind', () {
      expect(const PaymentDeclinedFailure().messageKey, 'payment.declined');
      expect(
        const PaymentInProgressFailure().messageKey,
        'payment.in_progress',
      );
      expect(const InvalidPaymentFailure().messageKey, 'payment.invalid');
      expect(
        const PaymentProcessingFailure().messageKey,
        'payment.processing_failed',
      );
    });

    test('is a Failure, and a switch over PaymentFailure is exhaustive', () {
      String name(PaymentFailure failure) => switch (failure) {
        PaymentDeclinedFailure() => 'declined',
        PaymentInProgressFailure() => 'in progress',
        InvalidPaymentFailure() => 'invalid',
        PaymentStartNotAllowedFailure() => 'not allowed',
        PaymentProcessingFailure() => 'processing',
      };

      expect(const InvalidPaymentFailure(), isA<Failure>());
      expect(name(const PaymentInProgressFailure()), 'in progress');
    });
  });

  test('PaymentResult compares by value', () {
    expect(_result, _result);
    expect(
      _result,
      isNot(
        PaymentResult(
          paymentId: 'bill-1',
          transactionId: 'tx-2',
          amount: const Money.minor(1100, Currency.usd),
          completedAt: DateTime.utc(2026, 10, 15, 12),
        ),
      ),
    );
  });
}
