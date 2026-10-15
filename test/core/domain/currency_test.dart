import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';

void main() {
  group('Currency', () {
    test('finds a known currency by its exact code', () {
      expect(Currency.fromCode('USD'), Currency.usd);
      expect(Currency.fromCode('JPY'), Currency.jpy);
    });

    test('returns null for an unknown or differently cased code', () {
      expect(Currency.fromCode('XXX'), isNull);
      expect(Currency.fromCode('usd'), isNull);
      expect(Currency.fromCode(''), isNull);
    });

    test('knows its minor unit digits', () {
      expect(Currency.usd.minorUnitDigits, 2);
      expect(Currency.jpy.minorUnitDigits, 0);
    });

    test('has unique codes', () {
      final codes = Currency.known.map((c) => c.code).toList();

      expect(codes.toSet(), hasLength(codes.length));
    });
  });
}
