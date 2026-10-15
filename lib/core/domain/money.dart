import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';

/// Mixing currencies is a programming error, not an expected failure.
class CurrencyMismatchError extends Error {
  CurrencyMismatchError(this.left, this.right);

  final Currency left;
  final Currency right;

  @override
  String toString() => 'CurrencyMismatchError: ${left.code} vs ${right.code}';
}

/// An amount of money: integer minor units (cents) plus a currency. Never a
/// `double`. There is no division or percentage on purpose: when one is needed
/// it must come with an explicit rounding mode.
final class Money extends Equatable implements Comparable<Money> {
  const Money.minor(this.minorUnits, this.currency);

  const Money.zero(Currency currency) : this.minor(0, currency);

  final int minorUnits;
  final Currency currency;

  /// The sum of [amounts], all in [currency] (so an empty list is a zero).
  static Money sum(Iterable<Money> amounts, Currency currency) {
    var total = Money.zero(currency);
    for (final amount in amounts) {
      total += amount;
    }
    return total;
  }

  bool get isZero => minorUnits == 0;
  bool get isPositive => minorUnits > 0;
  bool get isNegative => minorUnits < 0;

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money.minor(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money.minor(minorUnits - other.minorUnits, currency);
  }

  Money operator -() => Money.minor(-minorUnits, currency);

  Money times(int factor) => Money.minor(minorUnits * factor, currency);

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  @override
  int compareTo(Money other) {
    _requireSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  /// Plain decimal text without symbol, grouping or locale: `12.30`, `-0.05`,
  /// `1200` (JPY). Symbols and locale formatting belong to presentation.
  String toDecimalString() {
    final digits = currency.minorUnitDigits;
    final sign = minorUnits < 0 ? '-' : '';
    final absolute = minorUnits.abs();
    if (digits == 0) return '$sign$absolute';
    final divisor = _powerOfTen(digits);
    final whole = absolute ~/ divisor;
    final fraction = (absolute % divisor).toString().padLeft(digits, '0');
    return '$sign$whole.$fraction';
  }

  void _requireSameCurrency(Money other) {
    if (currency != other.currency) {
      throw CurrencyMismatchError(currency, other.currency);
    }
  }

  static int _powerOfTen(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  @override
  List<Object?> get props => [minorUnits, currency];

  @override
  String toString() => '${toDecimalString()} ${currency.code}';
}
