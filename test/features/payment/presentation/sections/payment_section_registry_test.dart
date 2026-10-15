import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';

import '../../helpers/payment_ui_harness.dart';

/// A section type that exists only in this test: nothing in the feature knows it.
final class _NoteSpec extends PaymentSectionSpec {
  const _NoteSpec(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

BrandConfig _retailWith(List<PaymentSectionSpec> sections) => BrandConfig(
  id: retailBrand.id,
  displayName: retailBrand.displayName,
  tokens: retailBrand.tokens,
  payment: PaymentScreenConfig(
    paymentId: retailBrand.payment.paymentId,
    sections: sections,
  ),
);

void main() {
  group('PaymentSectionRegistry', () {
    test('the standard registry supports the three built-in sections', () {
      final registry = PaymentSectionRegistry.standard();

      expect(registry.supports(const SummarySpec()), isTrue);
      expect(registry.supports(const BillBreakdownSpec()), isTrue);
      expect(
        registry.supports(const PromoBannerSpec(headline: 'h', body: 'b')),
        isTrue,
      );
    });

    test('an unregistered spec is not supported', () {
      expect(
        PaymentSectionRegistry.standard().supports(const _NoteSpec('x')),
        isFalse,
      );
    });

    test('adding returns a new registry and leaves the old one alone', () {
      final standard = PaymentSectionRegistry.standard();

      final extended = standard.adding<_NoteSpec>(
        (context, spec) => SliverToBoxAdapter(child: Text(spec.text)),
      );

      expect(extended.supports(const _NoteSpec('x')), isTrue);
      expect(standard.supports(const _NoteSpec('x')), isFalse);
      expect(extended.supports(const SummarySpec()), isTrue);
    });

    testWidgets('building an unregistered spec fails loudly, naming the type', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );

      expect(
        () => PaymentSectionRegistry.standard().build(
          context,
          const _NoteSpec('x'),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('_NoteSpec'),
          ),
        ),
      );
    });

    testWidgets('a new section shows up without changing the page', (
      tester,
    ) async {
      final registry = PaymentSectionRegistry.standard().adding<_NoteSpec>(
        (context, spec) => SliverToBoxAdapter(child: Text(spec.text)),
      );

      await tester.pumpPaymentPage(
        brand: _retailWith(const [
          SummarySpec(),
          _NoteSpec('A brand-new section'),
        ]),
        overrides: [paymentSectionRegistryProvider.overrideWithValue(registry)],
      );

      expect(find.text('A brand-new section'), findsOneWidget);
      expect(find.text('Retail Shop'), findsOneWidget);
    });
  });
}
