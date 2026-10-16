import 'package:secure_payment_portal/core/logging/logger.dart';

enum LogLevel { warning, error }

/// One thing the code said.
final class LogEntry {
  const LogEntry(this.level, this.message, {this.error, this.stackTrace});

  final LogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  /// Everything it said, as one string, to check that something is not in it.
  String get everything => '$level $message $error';

  @override
  String toString() => '$level: $message${error == null ? '' : ' ($error)'}';
}

/// A [Logger] that keeps what it is told, for a test to read.
final class RecordingLogger implements Logger {
  final List<LogEntry> entries = [];

  Iterable<LogEntry> get warnings =>
      entries.where((entry) => entry.level == LogLevel.warning);
  Iterable<LogEntry> get errors =>
      entries.where((entry) => entry.level == LogLevel.error);

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      entries.add(
        LogEntry(
          LogLevel.warning,
          message,
          error: error,
          stackTrace: stackTrace,
        ),
      );

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      entries.add(
        LogEntry(LogLevel.error, message, error: error, stackTrace: stackTrace),
      );
}
