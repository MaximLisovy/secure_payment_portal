import 'dart:developer' as developer;

/// Where the code says that something went wrong and was handled, so it does not
/// vanish. It is an interface so that a test can read what was said, and so that
/// the destination can change without touching the code that logs.
///
/// **What may be logged.** A place, an error code, a type name, a stack trace:
/// what is needed to find the problem. Never an amount tied to an identity, card
/// data, a token, a device fingerprint, or the text of an error that might carry
/// any of them. Callers pass `error.runtimeType` or a code, not `error.message`.
abstract interface class Logger {
  /// Something unexpected that the code recovered from.
  void warning(String message, {Object? error, StackTrace? stackTrace});

  /// Something that should not happen and was turned into a failure.
  void error(String message, {Object? error, StackTrace? stackTrace});
}

/// Writes to `dart:developer`'s log: it shows in DevTools and in the IDE's debug
/// console, and in release builds it costs nothing and prints nothing to logcat.
final class DeveloperLogger implements Logger {
  const DeveloperLogger({this.name = 'secure_payment_portal'});

  final String name;

  static const _warning = 900; // The level `package:logging` calls WARNING.
  static const _severe = 1000; // ...and SEVERE.

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      developer.log(
        message,
        name: name,
        level: _warning,
        error: error,
        stackTrace: stackTrace,
      );

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      developer.log(
        message,
        name: name,
        level: _severe,
        error: error,
        stackTrace: stackTrace,
      );
}

/// Says nothing. For code that is deliberately not logging, such as most tests.
final class SilentLogger implements Logger {
  const SilentLogger();

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {}
}
