import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/logging/logger.dart';

import '../../helpers/recording_logger.dart';

void main() {
  test('the developer logger takes a message, an error and a stack trace', () {
    const logger = DeveloperLogger();
    expect(() => logger.warning('careful'), returnsNormally);
    expect(
      () => logger.error(
        'broken',
        error: 'a type',
        stackTrace: StackTrace.current,
      ),
      returnsNormally,
    );
  });

  test('the silent logger says nothing and never fails', () {
    const logger = SilentLogger();
    expect(() => logger.warning('careful'), returnsNormally);
    expect(() => logger.error('broken', error: 1), returnsNormally);
  });

  test(
    'the recording logger keeps level, message, error and stack in order',
    () {
      final logger = RecordingLogger();
      final stack = StackTrace.current;

      logger
        ..warning('first')
        ..error('second', error: 'E', stackTrace: stack);

      expect(logger.entries.map((e) => e.level), [
        LogLevel.warning,
        LogLevel.error,
      ]);
      expect(logger.entries.map((e) => e.message), ['first', 'second']);
      expect(logger.errors.single.error, 'E');
      expect(logger.errors.single.stackTrace, stack);
    },
  );
}
