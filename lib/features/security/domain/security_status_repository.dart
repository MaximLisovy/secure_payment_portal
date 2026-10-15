import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/features/security/domain/security_status.dart';

/// Read side of device security. Depends on nothing about how it is measured.
abstract interface class SecurityStatusRepository {
  /// A fresh read of root and screen recording, never a cached value.
  Future<Result<SecurityStatus>> getStatus();

  /// A fresh status first, then the status again whenever screen recording
  /// changes. Never emits an error: anything that cannot be read becomes
  /// `unknown`, and the policy decides what that means.
  Stream<SecurityStatus> watchStatus();
}
