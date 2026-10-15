import 'package:secure_payment_portal/core/domain/money.dart';

/// Amounts as people read them: `$1,234.50`, `-$10.80`, `¥1,200`.
///
/// One convention for every currency: symbol first, comma grouping, dot as the
/// decimal separator. It is deliberately not locale-aware (that would need the
/// `intl` package, which is not in the stack); a locale-aware formatter can
/// replace this class without touching a caller.
abstract final class MoneyFormatter {
  static String format(Money money) {
    final decimal = money.toDecimalString();
    final negative = decimal.startsWith('-');
    final unsigned = negative ? decimal.substring(1) : decimal;
    final dot = unsigned.indexOf('.');
    final whole = dot < 0 ? unsigned : unsigned.substring(0, dot);
    final fraction = dot < 0 ? '' : unsigned.substring(dot);
    return '${negative ? '-' : ''}${money.currency.symbol}'
        '${_groupThousands(whole)}$fraction';
  }

  static String _groupThousands(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
