import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/core/design_system/theme/theme_factory.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_colors.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_density.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_motion.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_shape.dart';

ThemeData _themeOf(BrandConfig brand) =>
    ThemeFactory.build(brand.tokens, brightness: Brightness.light);

// Iterates the registry, so a newly registered brand is covered automatically.
void main() {
  final brands = BrandRegistry.standard.all.toList();

  for (final brand in brands) {
    group('brand ${brand.id}', () {
      test('builds a theme with all four token extensions', () {
        final theme = _themeOf(brand);

        expect(theme.extension<BrandColors>(), brand.tokens.colors);
        expect(theme.extension<BrandShape>(), brand.tokens.shape);
        expect(theme.extension<BrandDensity>(), brand.tokens.density);
        expect(theme.extension<BrandMotion>(), brand.tokens.motion);
      });
    });
  }

  test('every pair of registered brands can animate between themes', () {
    for (final from in brands) {
      for (final to in brands) {
        final mid = ThemeData.lerp(_themeOf(from), _themeOf(to), 0.5);

        expect(
          mid.extension<BrandColors>(),
          from.tokens.colors.lerp(to.tokens.colors, 0.5),
          reason: '${from.id} -> ${to.id}',
        );
      }
    }
  });
}
