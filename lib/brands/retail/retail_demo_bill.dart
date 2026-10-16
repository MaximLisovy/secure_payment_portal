import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';

const retailDemoPaymentId = 'retail-order-1042';

const retailDemoBill = DemoBill(
  id: retailDemoPaymentId,
  merchantName: 'Retail Shop',
  reference: 'Order #1042',
  currency: Currency.usd,
  lineItems: [
    BillLineItem(
      label: 'Wireless headphones',
      amount: Money.minor(8900, Currency.usd),
      kind: LineItemKind.charge,
    ),
    BillLineItem(
      label: 'Phone case',
      amount: Money.minor(1900, Currency.usd),
      kind: LineItemKind.charge,
    ),
    BillLineItem(
      label: 'Promo WELCOME10',
      amount: Money.minor(-1080, Currency.usd),
      kind: LineItemKind.discount,
    ),
    BillLineItem(
      label: 'Shipping',
      amount: Money.minor(499, Currency.usd),
      kind: LineItemKind.fee,
    ),
    BillLineItem(
      label: 'Sales tax',
      amount: Money.minor(720, Currency.usd),
      kind: LineItemKind.tax,
    ),
  ],
);
