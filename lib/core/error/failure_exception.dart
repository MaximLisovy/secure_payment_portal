import 'package:secure_payment_portal/core/error/failure.dart';

/// Carries a [Failure] through an API that can only report an error by throwing,
/// such as an `AsyncNotifier`'s `build`. It is used inside presentation state
/// only and is turned back into the [Failure] by [failureOfError] where the
/// error is shown, so an expected error never crosses a layer as an exception.
final class FailureException implements Exception {
  const FailureException(this.failure);

  final Failure failure;

  @override
  String toString() => 'FailureException(${failure.messageKey})';
}

/// The [Failure] behind an error held by an `AsyncValue`. Anything that is not a
/// [FailureException] is a bug and reads as an unexpected failure.
Failure failureOfError(Object error) =>
    error is FailureException ? error.failure : const UnexpectedFailure();
