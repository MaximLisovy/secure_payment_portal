import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';

/// A section type nobody in the feature knows about: the hierarchy is open, so a
/// new one needs no edit to an existing file.
final class _LoyaltySpec extends PaymentSectionSpec {
  const _LoyaltySpec(this.points);

  final int points;

  @override
  List<Object?> get props => [points];
}

void main() {
  group('PaymentSectionSpec', () {
    test('specs compare by value', () {
      expect(const SummarySpec(), const SummarySpec());
      expect(const BillBreakdownSpec(), const BillBreakdownSpec());
      expect(
        const PromoBannerSpec(headline: 'h', body: 'b'),
        const PromoBannerSpec(headline: 'h', body: 'b'),
      );
      expect(
        const PromoBannerSpec(headline: 'h', body: 'b'),
        isNot(const PromoBannerSpec(headline: 'h', body: 'other')),
      );
      expect(const SummarySpec(), isNot(const BillBreakdownSpec()));
    });

    test('a new section type can be added without touching the feature', () {
      expect(const _LoyaltySpec(10), const _LoyaltySpec(10));
      expect(const _LoyaltySpec(10), isNot(const _LoyaltySpec(11)));
      expect(const _LoyaltySpec(10), isA<PaymentSectionSpec>());
    });
  });

  group('PaymentScreenConfig', () {
    test('compares by bill id and ordered sections', () {
      const a = PaymentScreenConfig(
        paymentId: 'bill',
        sections: [SummarySpec(), BillBreakdownSpec()],
      );

      expect(
        a,
        const PaymentScreenConfig(
          paymentId: 'bill',
          sections: [SummarySpec(), BillBreakdownSpec()],
        ),
      );
      expect(
        a,
        isNot(
          const PaymentScreenConfig(
            paymentId: 'bill',
            sections: [BillBreakdownSpec(), SummarySpec()],
          ),
        ),
        reason: 'order matters: it is the layout',
      );
      expect(
        a,
        isNot(
          const PaymentScreenConfig(
            paymentId: 'other',
            sections: [SummarySpec(), BillBreakdownSpec()],
          ),
        ),
      );
    });
  });
}
