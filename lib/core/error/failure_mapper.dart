import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/error/failure.dart';

/// The one place that turns a data-layer error into a [Failure]. Repositories
/// with feature-specific codes (e.g. "already running") handle those first and
/// fall back to this.
Failure failureFromError(Object error) {
  return switch (error) {
    NetworkException() => const NetworkFailure(),
    NotFoundException() => const NotFoundFailure(),
    PlatformCallException(:final code) => PlatformFailure(code),
    UnsupportedException() => const UnsupportedFailure(),
    MalformedPayloadException() => const InvalidDataFailure(),
    _ => const UnexpectedFailure(),
  };
}
