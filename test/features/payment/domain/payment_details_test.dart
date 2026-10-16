import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';

import '../helpers/payment_fixtures.dart';

void main() {
  test('bill lines are copied and cannot be changed through the entity', () {
    final lines = [usdItem(100)];
    final details = detailsWith(lines);
    lines.clear();
    expect(details.total, const Money.minor(100, Currency.usd));
    expect(() => details.lineItems.clear(), throwsUnsupportedError);
  });

  group('PaymentDetails.total', () {
    test('is the sum of the line items', () {
      expect(sampleDetails.total, const Money.minor(1100, Currency.usd));
    });

    test('counts a discount as a reduction', () {
      final details = detailsWith([
        usdItem(8900),
        usdItem(-1080, LineItemKind.discount),
        usdItem(499, LineItemKind.fee),
      ]);

      expect(details.total, const Money.minor(8319, Currency.usd));
    });

    test('is a zero in the bill currency when there are no lines', () {
      expect(detailsWith(const []).total, const Money.zero(Currency.usd));
    });

    test(
      'cannot disagree with its lines: a foreign-currency line is an error',
      () {
        final details = detailsWith([
          usdItem(100),
          const BillLineItem(
            label: 'euro line',
            amount: Money.minor(100, Currency.eur),
            kind: LineItemKind.charge,
          ),
        ]);

        expect(() => details.total, throwsA(isA<CurrencyMismatchError>()));
      },
    );
  });

  group('PaymentDetails.isPayable', () {
    test('is true for a positive total', () {
      expect(sampleDetails.isPayable, isTrue);
    });

    test('is false with nothing to pay', () {
      expect(detailsWith(const []).isPayable, isFalse);
    });

    test('is false for a zero total', () {
      expect(
        detailsWith([
          usdItem(500),
          usdItem(-500, LineItemKind.discount),
        ]).isPayable,
        isFalse,
      );
    });

    test('is false for a negative total', () {
      expect(
        detailsWith([
          usdItem(500),
          usdItem(-900, LineItemKind.discount),
        ]).isPayable,
        isFalse,
      );
    });

    test('is false, without throwing, when a line is in another currency', () {
      final details = detailsWith([
        usdItem(1000),
        const BillLineItem(
          label: 'euro line',
          amount: Money.minor(1000, Currency.eur),
          kind: LineItemKind.charge,
        ),
      ]);

      expect(details.isPayable, isFalse);
    });
  });

  test('details compare by value', () {
    final same = PaymentDetails(
      id: 'bill-1',
      merchantName: 'Test Shop',
      reference: 'Order #1',
      currency: Currency.usd,
      lineItems: [
        const BillLineItem(
          label: 'Item',
          amount: Money.minor(1000, Currency.usd),
          kind: LineItemKind.charge,
        ),
        const BillLineItem(
          label: 'Tax',
          amount: Money.minor(100, Currency.usd),
          kind: LineItemKind.tax,
        ),
      ],
    );

    expect(same, sampleDetails);
    expect(detailsWith([usdItem(1000)]), isNot(sampleDetails));
  });
}
