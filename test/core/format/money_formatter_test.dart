import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/core/format/money_formatter.dart';

String _format(int minor, Currency currency) =>
    MoneyFormatter.format(Money.minor(minor, currency));

void main() {
  group('MoneyFormatter', () {
    test('puts the currency symbol first and keeps two decimals', () {
      expect(_format(10939, Currency.usd), r'$109.39');
      expect(_format(8961, Currency.eur), '€89.61');
      expect(_format(5, Currency.gbp), '£0.05');
      expect(_format(0, Currency.usd), r'$0.00');
    });

    test('groups thousands with commas', () {
      expect(_format(100000, Currency.usd), r'$1,000.00');
      expect(_format(123456789, Currency.usd), r'$1,234,567.89');
      expect(_format(99999, Currency.usd), r'$999.99');
    });

    test('puts the minus sign before the symbol', () {
      expect(_format(-1080, Currency.usd), r'-$10.80');
      expect(_format(-5, Currency.eur), '-€0.05');
      expect(_format(-123456, Currency.usd), r'-$1,234.56');
    });

    test('has no decimal point for a currency without a minor unit', () {
      expect(_format(1200, Currency.jpy), '¥1,200');
      expect(_format(-1200, Currency.jpy), '-¥1,200');
      expect(_format(0, Currency.jpy), '¥0');
    });
  });
}
