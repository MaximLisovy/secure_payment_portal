import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_providers.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/app/di/root_overrides.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/brands/brand_registration.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/brands/utility/utility_brand.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_colors.dart';

ProviderContainer _containerFor(BrandConfig brand) =>
    ProviderContainer.test(overrides: rootOverrides(initialBrand: brand));

void main() {
  group('activeBrandProvider', () {
    test('starts from the initial brand', () {
      final container = _containerFor(utilityBrand);

      expect(container.read(activeBrandProvider), utilityBrand);
    });

    test('select switches to another registered brand', () {
      final container = _containerFor(retailBrand);

      container.read(activeBrandProvider.notifier).select('utility');

      expect(container.read(activeBrandProvider), utilityBrand);
    });

    test('select with an unknown id throws and keeps the current brand', () {
      final container = _containerFor(retailBrand);

      expect(
        () => container.read(activeBrandProvider.notifier).select('nope'),
        throwsArgumentError,
      );
      expect(container.read(activeBrandProvider), retailBrand);
    });
  });

  group('themeProvider', () {
    test('builds the theme from the active brand tokens', () {
      final container = _containerFor(retailBrand);

      final theme = container.read(themeProvider);

      expect(theme.extension<BrandColors>(), retailBrand.tokens.colors);
      expect(
        theme.colorScheme.primary,
        retailBrand.tokens.colors.brandOnSurface,
      );
    });

    test('emits a new theme when the brand changes', () async {
      final container = _containerFor(retailBrand);
      final themes = <BrandColors?>[];
      container.listen(
        themeProvider,
        (_, next) => themes.add(next.extension<BrandColors>()),
        fireImmediately: true,
      );

      container.read(activeBrandProvider.notifier).select('utility');
      await container.pump();

      expect(themes, [retailBrand.tokens.colors, utilityBrand.tokens.colors]);
    });

    // Guards value equality end to end (tokens -> ThemeData). It cannot tell
    // whether `.select` skipped the recompute: an equal theme is not emitted
    // either way.
    test('does not emit when only non-token brand data changes', () async {
      // Same tokens, different id and display name.
      final twin = BrandConfig(
        id: 'retail-twin',
        displayName: 'Retail Twin',
        tokens: retailBrand.tokens,
        payment: retailBrand.payment,
      );
      final container = ProviderContainer.test(
        overrides: [
          ...rootOverrides(initialBrand: retailBrand),
          brandRegistryProvider.overrideWithValue(
            BrandRegistry([
              const BrandRegistration(
                brand: retailBrand,
                demoPaymentId: 'bill-1',
              ),
              BrandRegistration(brand: twin, demoPaymentId: 'bill-1'),
            ], defaultBrandId: 'retail'),
          ),
        ],
      );
      var emissions = 0;
      container.listen(themeProvider, (_, _) => emissions++);

      container.read(activeBrandProvider.notifier).select('retail-twin');
      await container.pump();

      expect(container.read(activeBrandProvider), twin);
      expect(emissions, 0);
    });
  });

  test('initialBrandProvider fails loudly when not overridden', () {
    final container = ProviderContainer.test();

    expect(() => container.read(initialBrandProvider), throwsA(anything));
  });
}
