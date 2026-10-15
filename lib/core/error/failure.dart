import 'package:equatable/equatable.dart';

/// Base of every expected error that crosses a layer boundary.
///
/// [messageKey] is a user-safe key for the l10n layer: never raw text, and never
/// anything sensitive (amounts tied to an identity, tokens, device fingerprints).
///
/// Core declares the generic failures below. Each feature declares its own
/// `sealed` sub-hierarchy (`PaymentFailure`, `SecurityFailure`), so a `switch`
/// over one feature's failures is exhaustive.
abstract class Failure extends Equatable {
  const Failure(this.messageKey);

  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// The remote end could not be reached or timed out.
final class NetworkFailure extends Failure {
  const NetworkFailure() : super('error.network');
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure() : super('error.not_found');
}

/// A response or platform payload was malformed or inconsistent.
final class InvalidDataFailure extends Failure {
  const InvalidDataFailure() : super('error.invalid_data');
}

/// The native side answered with an error. [code] is the channel error code.
final class PlatformFailure extends Failure {
  const PlatformFailure(this.code) : super('error.platform');

  final String code;

  @override
  List<Object?> get props => [messageKey, code];
}

/// There is no native implementation here (iOS, tests).
final class UnsupportedFailure extends Failure {
  const UnsupportedFailure() : super('error.unsupported');
}

/// Last resort for an error nobody modelled. Never silently dropped.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure() : super('error.unexpected');
}
