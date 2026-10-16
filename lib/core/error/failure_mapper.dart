import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/logging/logger.dart';

/// The one place that turns a data-layer error into a [Failure]. Repositories
/// with feature-specific codes (e.g. "already running") handle those first and
/// fall back to this.
///
/// An error with no failure of its own becomes [UnexpectedFailure], and that is
/// the one case that is also logged, with the error's type and [stackTrace] (when
/// the caller has one) and never its text: the user sees only "something went
/// wrong", and the log is where the cause survives. The other errors are expected
/// and already carry their own failure.
Failure failureFromError(
  Object error, {
  required Logger logger,
  StackTrace? stackTrace,
}) {
  return switch (error) {
    NetworkException() => const NetworkFailure(),
    NotFoundException() => const NotFoundFailure(),
    PlatformCallException(:final code) => PlatformFailure(code),
    UnsupportedException() => const UnsupportedFailure(),
    MalformedPayloadException() => const InvalidDataFailure(),
    _ => _unexpected(error, logger, stackTrace),
  };
}

Failure _unexpected(Object error, Logger logger, StackTrace? stackTrace) {
  logger.error(
    'An error with no failure of its own became UnexpectedFailure.',
    error: error.runtimeType,
    stackTrace: stackTrace,
  );
  return const UnexpectedFailure();
}
