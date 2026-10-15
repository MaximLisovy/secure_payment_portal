import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/start_payment_request_dto.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';

/// A 11.00 USD bill: an item plus tax.
const sampleDetails = PaymentDetails(
  id: 'bill-1',
  merchantName: 'Test Shop',
  reference: 'Order #1',
  currency: Currency.usd,
  lineItems: [
    BillLineItem(
      label: 'Item',
      amount: Money.minor(1000, Currency.usd),
      kind: LineItemKind.charge,
    ),
    BillLineItem(
      label: 'Tax',
      amount: Money.minor(100, Currency.usd),
      kind: LineItemKind.tax,
    ),
  ],
);

/// What [sampleDetails] becomes on the channel.
const sampleRequest = StartPaymentRequestDto(
  paymentId: 'bill-1',
  amountMinor: 1100,
  currency: 'USD',
);

PaymentDetails detailsWith(List<BillLineItem> items) => PaymentDetails(
  id: 'bill-x',
  merchantName: 'Test Shop',
  reference: 'Order #x',
  currency: Currency.usd,
  lineItems: items,
);

BillLineItem usdItem(int minor, [LineItemKind kind = LineItemKind.charge]) =>
    BillLineItem(
      label: 'line',
      amount: Money.minor(minor, Currency.usd),
      kind: kind,
    );
