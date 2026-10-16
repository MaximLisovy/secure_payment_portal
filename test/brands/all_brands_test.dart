import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/presentation/sections/bill_line_item_tile.dart';
import 'package:secure_payment_portal/features/payment/presentation/sections/payment_section_registry.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/pay_action_bar.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/payment_body.dart';

import '../features/payment/helpers/payment_ui_harness.dart';
import '../helpers/fake_bills.dart';

Finder _payButton() => find.descendant(
  of: find.byType(PayActionBar),
  matching: find.byType(FilledButton),
);

bool _payEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_payButton()).onPressed != null;

// Iterates the registry, so a newly registered brand is rendered automatically
// by the real payment page, with no test to write.
void main() {
  for (final brand in BrandRegistry.standard.all) {
    group('payment page for ${brand.id}', () {
      test('every section it declares has a widget', () {
        final registry = PaymentSectionRegistry.standard();

        for (final spec in brand.payment.sections) {
          expect(registry.supports(spec), isTrue, reason: '$spec');
        }
      });

      test('the app registration names an available demo bill', () {
        expect(
          FakeBills.all,
          contains(BrandRegistry.standard.demoPaymentIdFor(brand.id)),
        );
      });

      testWidgets('renders its bill without errors', (tester) async {
        await tester.pumpPaymentPage(brand: brand);

        expect(tester.takeException(), isNull);
        final bill =
            FakeBills.all[BrandRegistry.standard.demoPaymentIdFor(brand.id)]!;
        expect(find.text(bill.merchantName), findsOneWidget);
        expect(find.text(bill.reference), findsOneWidget);
        expect(_payButton(), findsOneWidget);
      });

      testWidgets('widgets read this brand\'s tokens', (tester) async {
        await tester.pumpPaymentPage(brand: brand);

        final context = tester.element(find.byType(PaymentBody));
        expect(context.brandColors, brand.tokens.colors);
        expect(context.brandShape, brand.tokens.shape);
        expect(context.brandDensity, brand.tokens.density);
        expect(context.brandMotion, brand.tokens.motion);
      });

      testWidgets('bill rows are as tall as the brand row height', (
        tester,
      ) async {
        await tester.pumpPaymentPage(brand: brand);

        // Only a brand that declares a breakdown has rows.
        for (final row in find.byType(BillLineItemTile).evaluate()) {
          expect(
            tester.getSize(find.byWidget(row.widget)).height,
            moreOrLessEquals(brand.tokens.density.rowHeight),
          );
        }
      });

      testWidgets('pays through to the receipt and can start again', (
        tester,
      ) async {
        await tester.pumpPaymentPage(brand: brand);
        expect(_payEnabled(tester), isTrue);

        await tester.tap(_payButton());
        await tester.pump();
        expect(find.text(AppStrings.processingTitle), findsOneWidget);

        // The fake takes five steps of 100 ms; the rest is the screen fading.
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.paymentSuccessful), findsOneWidget);

        await tester.tap(find.text(AppStrings.repeatDemoPayment));
        await tester.pumpAndSettle();
        expect(_payEnabled(tester), isTrue);

        await tester.unmountApp();
      });
    });
  }
}
