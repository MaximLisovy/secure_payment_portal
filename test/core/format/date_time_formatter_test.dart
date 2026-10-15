import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/format/date_time_formatter.dart';

void main() {
  group('DateTimeFormatter.utc', () {
    test('writes year, month, day, hour and minute with leading zeros', () {
      expect(
        DateTimeFormatter.utc(DateTime.utc(2026, 1, 5, 7, 3)),
        '2026-01-05 07:03 UTC',
      );
      expect(
        DateTimeFormatter.utc(DateTime.utc(2026, 10, 15, 12)),
        '2026-10-15 12:00 UTC',
      );
    });

    test('converts a local moment to UTC, so it reads the same everywhere', () {
      final local = DateTime.utc(2026, 10, 15, 12).toLocal();

      expect(DateTimeFormatter.utc(local), '2026-10-15 12:00 UTC');
    });

    test('pads a year below 1000', () {
      expect(
        DateTimeFormatter.utc(DateTime.utc(999, 12, 31, 23, 59)),
        '0999-12-31 23:59 UTC',
      );
    });
  });
}
