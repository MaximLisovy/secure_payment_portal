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

/// The system did not allow the payment to start, which happens when the app is
/// not in the foreground: a payment can only begin while the user is looking at
/// the app.
final class PaymentStartNotAllowedFailure extends PaymentFailure {
  const PaymentStartNotAllowedFailure() : super('payment.start_not_allowed');
}

/// Processing started but did not complete, for a reason other than a decline.
final class PaymentProcessingFailure extends PaymentFailure {
  const PaymentProcessingFailure() : super('payment.processing_failed');
}

/// The screen changed or went away before confirmation could start processing.
final class PaymentConfirmationObsoleteFailure extends PaymentFailure {
  const PaymentConfirmationObsoleteFailure()
    : super('payment.confirmation_obsolete');
}

/// The start may have been accepted. Reconcile this attempt; never blindly retry.
final class PaymentOutcomeUnknownFailure extends PaymentFailure {
  const PaymentOutcomeUnknownFailure() : super('payment.outcome_unknown');
}
