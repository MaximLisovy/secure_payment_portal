import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/core/design_system/theme/theme_factory.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_tokens.dart';

import '../helpers/component_contrast_table.dart';

ThemeData _themeOf(BrandTokens tokens) =>
    ThemeFactory.build(tokens, brightness: Brightness.light);

// Iterates the registry, so a newly registered brand is checked automatically.
void main() {
  for (final brand in BrandRegistry.standard.all) {
    test('${brand.id}: every component foreground meets its minimum', () {
      final failures = contrastFailures(_themeOf(brand.tokens));

      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }

  group('the contrast table', () {
    test('has unique rows covering both text and non-text UI', () {
      final names = componentContrastPairs.map((p) => p.name).toList();

      expect(names.toSet(), hasLength(names.length));
      expect(
        componentContrastPairs.map((p) => p.kind).toSet(),
        ContrastKind.values.toSet(),
      );
    });

    // The defect this table exists for: Retail once used its vivid fill color
    // (brandPrimary) as the foreground on cream surfaces, at about 2.6:1.
    test('catches the vivid brand fill used as a foreground', () {
      final retail = retailBrand.tokens;
      final vivid = BrandTokens(
        colors: retail.colors.copyWith(
          brandOnSurface: retail.colors.brandPrimary,
        ),
        shape: retail.shape,
        density: retail.density,
        motion: retail.motion,
      );

      final flagged = contrastFailures(_themeOf(vivid)).map((f) => f.pair);

      expect(
        flagged,
        containsAll([
          'text button label',
          'outlined button label',
          'outlined button border',
          'input focus ring',
          'list tile icon',
          'progress indicator',
          'text cursor and selection handles',
          // Widgets nobody themed read ColorScheme.primary.
          'default primary (switch, checkbox, slider, focus)',
        ]),
      );
    });

    // The decorative role is exempt from the table, so it must not leak into a
    // control: using it for the input border has to fail the table.
    test('catches the soft decorative outline used for a control', () {
      final retail = retailBrand.tokens;
      final soft = BrandTokens(
        colors: retail.colors.copyWith(outline: retail.colors.outlineSubtle),
        shape: retail.shape,
        density: retail.density,
        motion: retail.motion,
      );

      final flagged = contrastFailures(_themeOf(soft)).map((f) => f.pair);

      expect(flagged, contains('input border'));
    });

    test('fails loudly when a component theme leaves a color unset', () {
      expect(() => contrastFailures(ThemeData()), throwsStateError);
    });
  });
}
