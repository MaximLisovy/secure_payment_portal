import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';

/// Const host configuration for the simulated backend, separate from layout.
/// Registrations supply only the catalog that this binary should contain.
final class DemoBill {
  const DemoBill({
    required this.id,
    required this.merchantName,
    required this.reference,
    required this.currency,
    required this.lineItems,
  });

  final String id;
  final String merchantName;
  final String reference;
  final Currency currency;
  final List<BillLineItem> lineItems;

  PaymentDetails toDetails() => PaymentDetails(
    id: id,
    merchantName: merchantName,
    reference: reference,
    currency: currency,
    lineItems: lineItems,
  );
}
