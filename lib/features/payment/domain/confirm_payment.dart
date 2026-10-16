import 'package:secure_payment_portal/core/async/cancellation.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_failures.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_repository.dart';
import 'package:secure_payment_portal/features/security/security_domain.dart';

/// Confirms a payment: checks that it may happen on this device right now, and
/// only then starts processing.
///
/// A use case because it combines two repositories and the security policy.
/// It deliberately re-reads the device status instead of trusting whatever the
/// screen last saw: a recording may have started a moment ago.
final class ConfirmPayment {
  const ConfirmPayment({
    required SecurityStatusRepository security,
    required PaymentRepository payments,
    required SecurityPolicy policy,
  }) : _security = security,
       _payments = payments,
       _policy = policy;

  final SecurityStatusRepository _security;
  final PaymentRepository _payments;
  final SecurityPolicy _policy;

  /// Success means processing was accepted; follow it with `watchProgress`.
  ///
  /// Fails with `InvalidPaymentFailure` (nothing valid to pay),
  /// `SecurityBlockedFailure` (the policy said no, and processing never
  /// started), or whatever `startPayment` fails with, such as
  /// `PaymentInProgressFailure` on a double confirm.
  Future<Result<void>> call(
    PaymentDetails details, {
    required String attemptId,
    CancellationSignal? cancellation,
  }) async {
    if (!details.isPayable) return const Err(InvalidPaymentFailure());

    if (cancellation?.isCancelled == true) {
      return const Err(PaymentConfirmationObsoleteFailure());
    }
    final prepared = await _payments.preparePayment();
    if (cancellation?.isCancelled == true) {
      return const Err(PaymentConfirmationObsoleteFailure());
    }
    if (prepared is Err<void>) return prepared;

    // A status that cannot be read is an unknown one: the policy decides.
    final status =
        (await _security.getStatus()).valueOrNull ?? SecurityStatus.unknown;
    if (cancellation?.isCancelled == true) {
      return const Err(PaymentConfirmationObsoleteFailure());
    }
    final decision = _policy.evaluate(status);
    if (decision case SecurityBlocked(:final reason)) {
      return Err(SecurityBlockedFailure(reason));
    }

    return _payments.startPayment(details, attemptId: attemptId);
  }
}
