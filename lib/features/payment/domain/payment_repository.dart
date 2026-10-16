import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';

abstract interface class PaymentRepository {
  Future<Result<PaymentDetails>> getPaymentDetails(String paymentId);

  /// Complete user interaction before the use case makes its final security read.
  Future<Result<void>> preparePayment();

  /// Asks for processing to begin. A success means it was accepted, not that
  /// it finished: follow it with [watchProgress]. Fails with
  /// `PaymentInProgressFailure` if a payment is already running.
  Future<Result<void>> startPayment(
    PaymentDetails details, {
    required String attemptId,
  });

  /// Cancels only this attempt. A stale ID or nothing running is a successful no-op.
  Future<Result<void>> cancelPayment({required String attemptId});

  /// The current state first (so a listener that arrives late, or after the
  /// app returns, still sees a running payment), then every change. Never
  /// emits an error: anything unreadable becomes a [PaymentFailed]. Each call
  /// returns a new single-subscription stream.
  Stream<PaymentProgress> watchProgress();

  /// Current retained state for the attempt. Idle never authorizes a retry.
  Future<Result<PaymentProgress>> getPaymentSnapshot({
    required String attemptId,
  });
}
