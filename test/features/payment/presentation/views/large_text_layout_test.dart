import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/format/money_formatter.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';
import 'package:secure_payment_portal/features/payment/presentation/sections/bill_breakdown_section.dart';
import 'package:secure_payment_portal/features/payment/presentation/sections/bill_line_item_tile.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/pay_action_bar.dart';

import '../../../../helpers/pump_app.dart';
import '../../helpers/payment_ui_harness.dart';

/// Large system text on a narrow screen: the worst a phone setting can do to
/// the layout. A render overflow is a thrown error in a test, so a clean pump
/// already says nothing overflowed; the tests add what it cannot see (a row
/// taller than its text, an amount cut off, a button out of reach).
const _textScale = 2.0;
const _narrow = Size(280, 560);

void _large(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = _textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

final _awkwardBill = PaymentDetails(
  id: 'awkward',
  merchantName: 'Merchant',
  reference: 'REF-1',
  currency: Currency.usd,
  lineItems: const [
    BillLineItem(
      label: 'A line item whose label is far too long to fit on one line',
      amount: Money.minor(123456789012, Currency.usd),
      kind: LineItemKind.charge,
    ),
    BillLineItem(
      label: 'Loyalty discount applied to this order',
      amount: Money.minor(-1050, Currency.usd),
      kind: LineItemKind.discount,
    ),
    BillLineItem(
      label: 'VAT',
      amount: Money.minor(1999, Currency.usd),
      kind: LineItemKind.tax,
    ),
  ],
);

// Iterates the registry, so a newly registered brand gets the same checks.
void main() {
  for (final brand in BrandRegistry.standard.all) {
    group('large text and a narrow screen for ${brand.id}', () {
      testWidgets('bill rows grow with the text and keep the amount whole', (
        tester,
      ) async {
        _large(tester, _narrow);
        await tester.pumpApp(
          const Scaffold(
            body: CustomScrollView(slivers: [BillBreakdownSection()]),
          ),
          brand: brand,
          overrides: [
            loadedPaymentDetailsProvider.overrideWithValue(_awkwardBill),
          ],
        );

        expect(tester.takeException(), isNull);
        final density = brand.tokens.density;
        final tiles = find.byType(BillLineItemTile);
        expect(tiles, findsNWidgets(_awkwardBill.lineItems.length));
        final heights = {
          for (final t in tiles.evaluate())
            tester.getSize(find.byWidget(t.widget)).height,
        };
        expect(heights, hasLength(1), reason: 'every row shares one extent');

        for (final item in _awkwardBill.lineItems) {
          final tile = find.widgetWithText(BillLineItemTile, item.label);
          final tileRect = tester.getRect(tile);
          final label = tester.getRect(
            find.descendant(of: tile, matching: find.text(item.label)),
          );
          final amount = tester.getRect(
            find.descendant(
              of: tile,
              matching: find.text(MoneyFormatter.format(item.amount)),
            ),
          );

          expect(tileRect.height, greaterThanOrEqualTo(density.rowHeight));
          expect(
            label.height + 2 * density.spaceSm,
            lessThanOrEqualTo(tileRect.height),
            reason: 'the text fits in its row at ${_textScale}x',
          );
          expect(
            amount.right,
            lessThanOrEqualTo(tileRect.right - density.spaceMd + 0.5),
          );
          expect(
            amount.width,
            lessThanOrEqualTo(
              (tileRect.width - 2 * density.spaceMd) *
                      billAmountMaxWidthFraction +
                  0.5,
            ),
            reason: 'the amount column is capped',
          );
          expect(
            label.width,
            greaterThan(60),
            reason: 'the amount does not squeeze the label away',
          );
        }
      });

      testWidgets('the review page lays out and can still be paid', (
        tester,
      ) async {
        _large(tester, _narrow);
        await tester.pumpPaymentPage(brand: brand);

        expect(tester.takeException(), isNull);
        final pay = find.descendant(
          of: find.byType(PayActionBar),
          matching: find.byType(FilledButton),
        );
        expect(pay.hitTestable(), findsOneWidget);
      });

      testWidgets('the processing view scrolls to the cancel button on a '
          'short screen', (tester) async {
        _large(tester, const Size(280, 320));
        final flow = FixedFlow(
          const PaymentFlowProcessing(
            percent: 37,
            cancellationFailure: PlatformFailure('UNAVAILABLE'),
          ),
        );
        await tester.pumpApp(
          const PaymentConfirmationPage(title: 'Test'),
          brand: brand,
          overrides: [fixedFlowOverride(flow), ...instantBackend()],
        );
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        final cancel = find.widgetWithText(OutlinedButton, AppStrings.cancel);
        expect(
          cancel.hitTestable(),
          findsNothing,
          reason: 'the button starts below the visible area',
        );
        await tester.ensureVisible(cancel);
        await tester.pumpAndSettle();
        expect(cancel.hitTestable(), findsOneWidget);
        await tester.tap(cancel);
        expect(flow.calls, contains('cancel'));
        expect(find.text(AppStrings.cancellationFailed), findsOneWidget);
      });
    });
  }
}
