import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_progress_dto.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_failures.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_result.dart';

/// Progress DTO → entity. A value outside its range, an unknown currency or a
/// missing field for the state throws a [MalformedPayloadException].
abstract final class PaymentProgressMapper {
  static PaymentProgress toEntity(PaymentProgressDto dto) {
    return switch (dto.state) {
      PaymentChannel.stateIdle => const PaymentIdle(),
      PaymentChannel.stateRunning => _running(dto),
      PaymentChannel.stateSucceeded => _succeeded(dto),
      PaymentChannel.stateFailed => PaymentFailed(
        failureFromCode(_required(dto.errorCode, 'errorCode')),
      ),
      PaymentChannel.stateCancelled => const PaymentCancelled(),
      _ => throw const MalformedPayloadException(
        'payment progress has an unknown state',
      ),
    };
  }

  /// A code this app version does not know is still a failure, never ignored.
  static Failure failureFromCode(String code) {
    return switch (code) {
      PaymentChannel.failureDeclined => const PaymentDeclinedFailure(),
      _ => const PaymentProcessingFailure(),
    };
  }

  static PaymentProgress _running(PaymentProgressDto dto) {
    final percent = _required(dto.percent, 'percent');
    if (percent < 0 || percent > 100) {
      throw const MalformedPayloadException('payment progress: percent range');
    }
    return PaymentInProgress(_required(dto.paymentId, 'paymentId'), percent);
  }

  static PaymentProgress _succeeded(PaymentProgressDto dto) {
    final code = _required(dto.currency, 'currency');
    final currency = Currency.fromCode(code);
    if (currency == null) {
      throw const MalformedPayloadException(
        'payment progress: unknown currency',
      );
    }
    return PaymentSucceeded(
      PaymentResult(
        paymentId: _required(dto.paymentId, 'paymentId'),
        transactionId: _required(dto.transactionId, 'transactionId'),
        amount: Money.minor(
          _required(dto.amountMinor, 'amountMinor'),
          currency,
        ),
        completedAt: DateTime.fromMillisecondsSinceEpoch(
          _required(dto.completedAtMillis, 'completedAtMillis'),
          isUtc: true,
        ),
      ),
    );
  }

  static T _required<T>(T? value, String field) {
    if (value == null) {
      throw MalformedPayloadException('payment progress: missing "$field"');
    }
    return value;
  }
}
