import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/core/error/failure.dart';

/// Whether the secure window the app asked for is in effect.
sealed class SecureWindowState extends Equatable {
  const SecureWindowState();
}

/// No screen needs protection right now.
final class SecureWindowIdle extends SecureWindowState {
  const SecureWindowIdle();

  @override
  List<Object?> get props => [];
}

final class SecureWindowProtected extends SecureWindowState {
  const SecureWindowProtected();

  @override
  List<Object?> get props => [];
}

/// A screen needs protection but the platform could not provide it. The
/// security policy reads this from the status and blocks payment; [retry] may
/// succeed later.
final class SecureWindowFailed extends SecureWindowState {
  const SecureWindowFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
