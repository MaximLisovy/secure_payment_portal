import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/app.dart';
import 'package:secure_payment_portal/app/brand/brand_providers.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/app/brand_preview/brand_preview_view.dart';
import 'package:secure_payment_portal/app/di/root_overrides.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/brands/utility/utility_brand.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  BrandConfig brand,
) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: disableProviderRetry,
      overrides: rootOverrides(initialBrand: brand),
      child: const App(),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(App)));
}

Color _primaryOnScreen(WidgetTester tester) =>
    tester.element(find.byType(BrandPreviewView)).brandColors.brandPrimary;

void main() {
  testWidgets('uses the initial brand for title and theme', (tester) async {
    await _pumpApp(tester, utilityBrand);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, utilityBrand.displayName);
    expect(_primaryOnScreen(tester), utilityBrand.tokens.colors.brandPrimary);
  });

  testWidgets('switching the brand animates the theme instead of snapping', (
    tester,
  ) async {
    final container = await _pumpApp(tester, retailBrand);
    final from = retailBrand.tokens.colors.brandPrimary;
    final to = utilityBrand.tokens.colors.brandPrimary;
    expect(_primaryOnScreen(tester), from);

    container.read(activeBrandProvider.notifier).select('utility');
    await tester.pump();
    await tester.pump(utilityBrand.tokens.motion.medium ~/ 4);

    final midway = _primaryOnScreen(tester);
    expect(midway, isNot(from));
    expect(midway, isNot(to));

    await tester.pumpAndSettle();
    expect(_primaryOnScreen(tester), to);
  });

  testWidgets('the brand switcher lists every registered brand and switches', (
    tester,
  ) async {
    final container = await _pumpApp(tester, retailBrand);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    for (final brand in BrandRegistry.standard.all) {
      expect(
        find.widgetWithText(PopupMenuItem<String>, brand.displayName),
        findsOneWidget,
        reason: brand.id,
      );
    }

    await tester.tap(
      find.widgetWithText(PopupMenuItem<String>, utilityBrand.displayName),
    );
    await tester.pumpAndSettle();

    expect(container.read(activeBrandProvider), utilityBrand);
    expect(_primaryOnScreen(tester), utilityBrand.tokens.colors.brandPrimary);
    expect(find.text(utilityBrand.displayName), findsOneWidget);
  });
}
