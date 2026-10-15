import 'package:secure_payment_portal/core/error/failure.dart';

/// Everything the payment feature can fail with, besides the generic failures
/// from core. Sealed, so a `switch` over it is exhaustive.
sealed class PaymentFailure extends Failure {
  const PaymentFailure(super.messageKey);
}

/// The payer's side refused the payment.
final class PaymentDeclinedFailure extends PaymentFailure {
  const PaymentDeclinedFailure() : super('payment.declined');
}

/// A payment is already running; only one at a time.
final class PaymentInProgressFailure extends PaymentFailure {
  const PaymentInProgressFailure() : super('payment.in_progress');
}

/// There is nothing valid to pay (empty, zero or negative total, bad request).
final class InvalidPaymentFailure extends PaymentFailure {
  const InvalidPaymentFailure() : super('payment.invalid');
}

/// Processing started but did not complete, for a reason other than a decline.
final class PaymentProcessingFailure extends PaymentFailure {
  const PaymentProcessingFailure() : super('payment.processing_failed');
}
