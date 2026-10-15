import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/app/brand_preview/brand_preview_page.dart';
import 'package:secure_payment_portal/app/brand_preview/brand_preview_view.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';

import '../helpers/pump_app.dart';

// Iterates the registry, so a newly registered brand is rendered automatically.
void main() {
  for (final brand in BrandRegistry.standard.all) {
    group('preview page for ${brand.id}', () {
      testWidgets('renders every section and the brand name', (tester) async {
        await tester.pumpApp(const BrandPreviewPage(), brand: brand);

        expect(tester.takeException(), isNull);
        expect(find.text(brand.displayName), findsOneWidget);
        for (final heading in [
          AppStrings.previewColors,
          AppStrings.previewShape,
          AppStrings.previewControls,
          AppStrings.previewRows,
          AppStrings.previewMotion,
        ]) {
          expect(find.text(heading), findsOneWidget, reason: heading);
        }
      });

      testWidgets('widgets read this brand\'s tokens', (tester) async {
        await tester.pumpApp(const BrandPreviewPage(), brand: brand);

        final context = tester.element(find.byType(BrandPreviewView));
        expect(context.brandColors, brand.tokens.colors);
        expect(context.brandShape, brand.tokens.shape);
        expect(context.brandDensity, brand.tokens.density);
        expect(context.brandMotion, brand.tokens.motion);
      });

      testWidgets('list rows are as tall as the brand row height', (
        tester,
      ) async {
        await tester.pumpApp(const BrandPreviewPage(), brand: brand);

        final rows = find.byType(ListTile);
        expect(rows, findsWidgets);
        for (final row in rows.evaluate()) {
          expect(
            tester.getSize(find.byWidget(row.widget)).height,
            moreOrLessEquals(brand.tokens.density.rowHeight),
          );
        }
      });
    });
  }
}
