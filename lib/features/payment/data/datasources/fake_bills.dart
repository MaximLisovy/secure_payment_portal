import 'package:secure_payment_portal/features/payment/data/dtos/payment_details_dto.dart';

/// The bills the fake backend knows. A brand's payment config names the one it
/// shows, so no code anywhere asks which brand is running.
abstract final class FakeBills {
  static const String retailOrderId = 'retail-order-1042';
  static const String utilityBillId = 'utility-bill-2026-10';

  /// A shop order with a promo discount: 109.39 USD.
  static const PaymentDetailsDto retailOrder = PaymentDetailsDto(
    id: retailOrderId,
    merchantName: 'Retail Shop',
    reference: 'Order #1042',
    currency: 'USD',
    lineItems: [
      BillLineItemDto(
        label: 'Wireless headphones',
        amountMinor: 8900,
        kind: 'charge',
      ),
      BillLineItemDto(label: 'Phone case', amountMinor: 1900, kind: 'charge'),
      BillLineItemDto(
        label: 'Promo WELCOME10',
        amountMinor: -1080,
        kind: 'discount',
      ),
      BillLineItemDto(label: 'Shipping', amountMinor: 499, kind: 'fee'),
      BillLineItemDto(label: 'Sales tax', amountMinor: 720, kind: 'tax'),
    ],
  );

  /// A utility bill with usage, fees, tax and a credit: 89.61 EUR.
  static const PaymentDetailsDto utilityBill = PaymentDetailsDto(
    id: utilityBillId,
    merchantName: 'Utility Pay',
    reference: 'Invoice 2026-10',
    currency: 'EUR',
    lineItems: [
      BillLineItemDto(
        label: 'Electricity, 320 kWh',
        amountMinor: 6400,
        kind: 'charge',
      ),
      BillLineItemDto(label: 'Grid fee', amountMinor: 1250, kind: 'fee'),
      BillLineItemDto(label: 'Service fee', amountMinor: 300, kind: 'fee'),
      BillLineItemDto(label: 'VAT 19%', amountMinor: 1511, kind: 'tax'),
      BillLineItemDto(
        label: 'Loyalty credit',
        amountMinor: -500,
        kind: 'discount',
      ),
    ],
  );

  static const Map<String, PaymentDetailsDto> all = {
    retailOrderId: retailOrder,
    utilityBillId: utilityBill,
  };
}
