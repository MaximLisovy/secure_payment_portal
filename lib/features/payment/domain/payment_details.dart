import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';

/// What a bill line is, so presentation can style it (a tax is not a charge).
enum LineItemKind { charge, tax, fee, discount }

final class BillLineItem extends Equatable {
  const BillLineItem({
    required this.label,
    required this.amount,
    required this.kind,
  });

  /// Text supplied by the backend (an item or a utility's own wording).
  final String label;

  /// Signed: a discount is negative.
  final Money amount;
  final LineItemKind kind;

  @override
  List<Object?> get props => [label, amount, kind];
}

/// A bill to pay: who gets paid, what for, and the line items that add up to
/// the total. The total is derived, so it can never disagree with the lines.
final class PaymentDetails extends Equatable {
  PaymentDetails({
    required this.id,
    required this.merchantName,
    required this.reference,
    required this.currency,
    required List<BillLineItem> lineItems,
  }) : lineItems = List.unmodifiable(lineItems);

  final String id;
  final String merchantName;

  /// What the payer recognises: an order or invoice number.
  final String reference;
  final Currency currency;
  final List<BillLineItem> lineItems;

  /// The sum of the line items. Throws `CurrencyMismatchError` if a line is in
  /// another currency; check [isPayable] first when the source is not trusted.
  Money get total => Money.sum(lineItems.map((item) => item.amount), currency);

  /// Whether there is something positive to pay, in one currency.
  bool get isPayable =>
      lineItems.isNotEmpty &&
      lineItems.every((item) => item.amount.currency == currency) &&
      total.isPositive;

  @override
  List<Object?> get props => [id, merchantName, reference, currency, lineItems];
}
