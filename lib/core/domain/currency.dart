import 'package:equatable/equatable.dart';

/// An ISO 4217 currency and how many decimal digits its minor unit has.
final class Currency extends Equatable {
  const Currency._(this.code, this.minorUnitDigits);

  static const usd = Currency._('USD', 2);
  static const eur = Currency._('EUR', 2);
  static const gbp = Currency._('GBP', 2);

  /// Has no minor unit, which exercises the zero-digit formatting path.
  static const jpy = Currency._('JPY', 0);

  static const List<Currency> known = [usd, eur, gbp, jpy];

  final String code;
  final int minorUnitDigits;

  /// The known currency with this exact upper-case [code], or null.
  static Currency? fromCode(String code) {
    for (final currency in known) {
      if (currency.code == code) return currency;
    }
    return null;
  }

  @override
  List<Object?> get props => [code, minorUnitDigits];
}
