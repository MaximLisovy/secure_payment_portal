/// A moment as `2026-10-15 12:00 UTC`, without the `intl` package. Always UTC:
/// a receipt must read the same on every device.
abstract final class DateTimeFormatter {
  static String utc(DateTime moment) {
    final t = moment.toUtc();
    return '${_pad(t.year, 4)}-${_pad(t.month)}-${_pad(t.day)} '
        '${_pad(t.hour)}:${_pad(t.minute)} UTC';
  }

  static String _pad(int value, [int width = 2]) =>
      value.toString().padLeft(width, '0');
}
