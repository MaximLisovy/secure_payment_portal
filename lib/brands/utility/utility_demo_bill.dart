import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';

const utilityDemoPaymentId = 'utility-bill-2026-10';

const utilityDemoBill = DemoBill(
  id: utilityDemoPaymentId,
  merchantName: 'Utility Pay',
  reference: 'Invoice 2026-10',
  currency: Currency.eur,
  lineItems: [
    BillLineItem(
      label: 'Electricity, 320 kWh',
      amount: Money.minor(6400, Currency.eur),
      kind: LineItemKind.charge,
    ),
    BillLineItem(
      label: 'Grid fee',
      amount: Money.minor(1250, Currency.eur),
      kind: LineItemKind.fee,
    ),
    BillLineItem(
      label: 'Service fee',
      amount: Money.minor(300, Currency.eur),
      kind: LineItemKind.fee,
    ),
    BillLineItem(
      label: 'VAT 19%',
      amount: Money.minor(1511, Currency.eur),
      kind: LineItemKind.tax,
    ),
    BillLineItem(
      label: 'Loyalty credit',
      amount: Money.minor(-500, Currency.eur),
      kind: LineItemKind.discount,
    ),
  ],
);
