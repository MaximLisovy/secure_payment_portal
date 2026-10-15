import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';

void main() {
  const usd = Currency.usd;
  const eur = Currency.eur;
  const jpy = Currency.jpy;

  group('Money arithmetic', () {
    test('adds and subtracts in minor units', () {
      expect(
        const Money.minor(1050, usd) + const Money.minor(250, usd),
        const Money.minor(1300, usd),
      );
      expect(
        const Money.minor(1050, usd) - const Money.minor(250, usd),
        const Money.minor(800, usd),
      );
    });

    test('negates and multiplies by a whole factor', () {
      expect(-const Money.minor(500, usd), const Money.minor(-500, usd));
      expect(
        const Money.minor(500, usd).times(3),
        const Money.minor(1500, usd),
      );
      expect(const Money.minor(500, usd).times(0), const Money.zero(usd));
    });

    test('the sum of nothing is a zero in the given currency', () {
      expect(Money.sum(const [], eur), const Money.zero(eur));
    });

    test('sums a mix of charges and discounts', () {
      final total = Money.sum(const [
        Money.minor(8900, usd),
        Money.minor(-1080, usd),
        Money.minor(499, usd),
      ], usd);

      expect(total, const Money.minor(8319, usd));
    });

    test('never loses a cent to floating point', () {
      var total = const Money.zero(usd);
      for (var i = 0; i < 10; i++) {
        total += const Money.minor(10, usd); // ten times 0.10
      }

      expect(total, const Money.minor(100, usd));
    });
  });

  group('Money comparison and sign', () {
    test('orders amounts of the same currency', () {
      const small = Money.minor(100, usd);
      const large = Money.minor(200, usd);

      expect(small < large, isTrue);
      expect(small <= small, isTrue);
      expect(large > small, isTrue);
      expect(large >= large, isTrue);
      expect(small.compareTo(large), isNegative);
    });

    test('reports its sign', () {
      expect(const Money.minor(1, usd).isPositive, isTrue);
      expect(const Money.minor(-1, usd).isNegative, isTrue);
      expect(const Money.zero(usd).isZero, isTrue);
      expect(const Money.zero(usd).isPositive, isFalse);
    });

    test('equal only with the same amount and currency', () {
      expect(const Money.minor(100, usd), const Money.minor(100, usd));
      expect(const Money.minor(100, usd), isNot(const Money.minor(100, eur)));
      expect(const Money.minor(100, usd), isNot(const Money.minor(101, usd)));
    });
  });

  group('Money currency mismatch', () {
    test('adding, subtracting or comparing mixed currencies is an error', () {
      const dollars = Money.minor(100, usd);
      const euros = Money.minor(100, eur);

      expect(() => dollars + euros, throwsA(isA<CurrencyMismatchError>()));
      expect(() => dollars - euros, throwsA(isA<CurrencyMismatchError>()));
      expect(() => dollars < euros, throwsA(isA<CurrencyMismatchError>()));
      expect(
        () => dollars.compareTo(euros),
        throwsA(isA<CurrencyMismatchError>()),
      );
    });

    test('summing mixed currencies is an error', () {
      expect(
        () => Money.sum(const [Money.minor(1, usd), Money.minor(1, eur)], usd),
        throwsA(isA<CurrencyMismatchError>()),
      );
    });
  });

  group('Money.toDecimalString', () {
    test('pads the fraction to the currency digits', () {
      expect(const Money.minor(1230, usd).toDecimalString(), '12.30');
      expect(const Money.minor(5, usd).toDecimalString(), '0.05');
      expect(const Money.zero(usd).toDecimalString(), '0.00');
      expect(const Money.minor(100, usd).toDecimalString(), '1.00');
    });

    test('keeps the sign on amounts below one unit', () {
      expect(const Money.minor(-5, usd).toDecimalString(), '-0.05');
      expect(const Money.minor(-1230, usd).toDecimalString(), '-12.30');
    });

    test('has no decimal point for a currency without a minor unit', () {
      expect(const Money.minor(1200, jpy).toDecimalString(), '1200');
      expect(const Money.minor(-1200, jpy).toDecimalString(), '-1200');
      expect(const Money.zero(jpy).toDecimalString(), '0');
    });

    test('handles large amounts without grouping or symbols', () {
      expect(const Money.minor(123456789, usd).toDecimalString(), '1234567.89');
    });

    test('toString appends the currency code', () {
      expect(const Money.minor(1230, eur).toString(), '12.30 EUR');
    });
  });
}
