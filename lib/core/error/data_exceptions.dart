/// Errors a data source may throw. They live inside the data layer only:
/// repositories catch them and map them to a `Failure` (`failureFromError`), so
/// they never reach domain or presentation.
///
/// Fakes and the real channel-based sources throw the same types, which is what
/// lets one replace the other unchanged.
sealed class DataSourceException implements Exception {
  const DataSourceException();
}

final class NetworkException extends DataSourceException {
  const NetworkException();
}

final class NotFoundException extends DataSourceException {
  const NotFoundException();
}

/// The native side replied with an error (`PlatformException` in Dart).
final class PlatformCallException extends DataSourceException {
  const PlatformCallException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => 'PlatformCallException($code)';
}

/// There is no native implementation (`MissingPluginException`: iOS, tests).
final class UnsupportedException extends DataSourceException {
  const UnsupportedException();
}

/// A payload is not in the documented shape. [message] names the field and what
/// was wrong, never its value.
final class MalformedPayloadException extends DataSourceException {
  const MalformedPayloadException(this.message);

  final String message;

  @override
  String toString() => 'MalformedPayloadException($message)';
}
