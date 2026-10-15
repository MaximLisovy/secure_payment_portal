import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/features/security/domain/security_decision.dart';

/// Everything the security feature can fail with, besides the generic
/// failures from core. Sealed, so a `switch` over it is exhaustive.
sealed class SecurityFailure extends Failure {
  const SecurityFailure(super.messageKey);
}

/// The policy refused the action. [reason] says why.
final class SecurityBlockedFailure extends SecurityFailure {
  SecurityBlockedFailure(this.reason) : super(reason.messageKey);

  final SecurityBlockReason reason;

  @override
  List<Object?> get props => [messageKey, reason];
}
