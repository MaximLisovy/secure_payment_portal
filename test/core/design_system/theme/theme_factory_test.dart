import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/design_system/theme/theme_factory.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_colors.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_density.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_motion.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_shape.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_tokens.dart';

import '../../../helpers/token_fixtures.dart';

ThemeData _build(BrandTokens tokens) =>
    ThemeFactory.build(tokens, brightness: Brightness.light);

void main() {
  for (final (name, tokens) in [('A', sampleTokensA), ('B', sampleTokensB)]) {
    group('ThemeFactory.build with tokens $name', () {
      late ThemeData theme;

      setUp(() => theme = _build(tokens));

      test('registers all four token extensions', () {
        expect(theme.extension<BrandColors>(), tokens.colors);
        expect(theme.extension<BrandShape>(), tokens.shape);
        expect(theme.extension<BrandDensity>(), tokens.density);
        expect(theme.extension<BrandMotion>(), tokens.motion);
      });

      test('color scheme roles come from the color tokens', () {
        final scheme = theme.colorScheme;

        expect(scheme.primary, tokens.colors.brandPrimary);
        expect(scheme.onPrimary, tokens.colors.onBrandPrimary);
        expect(scheme.secondary, tokens.colors.brandAccent);
        expect(scheme.error, tokens.colors.danger);
        expect(scheme.surface, tokens.colors.surface);
        expect(scheme.onSurface, tokens.colors.onSurface);
        expect(scheme.outline, tokens.colors.outline);
        expect(theme.scaffoldBackgroundColor, tokens.colors.canvas);
      });

      test('theme-level settings come from density and motion tokens', () {
        expect(theme.visualDensity, tokens.density.visualDensity);
        expect(theme.pageTransitionsTheme, tokens.motion.pageTransitions);
      });

      test('filled button style comes from shape and density tokens', () {
        final style = theme.filledButtonTheme.style!;

        expect(
          style.minimumSize!.resolve({}),
          Size.square(tokens.density.controlHeight),
        );
        expect(
          style.shape!.resolve({}),
          RoundedRectangleBorder(borderRadius: tokens.shape.borderRadiusMd),
        );
        expect(style.animationDuration, tokens.motion.fast);
      });

      test(
        'fills use brandPrimary, foregrounds on surfaces use brandOnSurface',
        () {
          final c = tokens.colors;
          const enabled = <WidgetState>{};

          // Fills.
          expect(
            theme.filledButtonTheme.style?.backgroundColor?.resolve(enabled),
            c.brandPrimary,
          );
          expect(
            theme.filledButtonTheme.style?.foregroundColor?.resolve(enabled),
            c.onBrandPrimary,
          );
          expect(theme.appBarTheme.backgroundColor, c.brandPrimary);
          // Foregrounds on surfaces.
          expect(
            theme.textButtonTheme.style?.foregroundColor?.resolve(enabled),
            c.brandOnSurface,
          );
          expect(
            theme.outlinedButtonTheme.style?.foregroundColor?.resolve(enabled),
            c.brandOnSurface,
          );
          expect(
            theme.outlinedButtonTheme.style?.side?.resolve(enabled)?.color,
            c.brandOnSurface,
          );
          expect(
            theme.inputDecorationTheme.focusedBorder?.borderSide.color,
            c.brandOnSurface,
          );
          expect(theme.listTileTheme.iconColor, c.brandOnSurface);
          expect(theme.progressIndicatorTheme.color, c.brandOnSurface);
          expect(theme.textSelectionTheme.cursorColor, c.brandOnSurface);
        },
      );

      test('card comes from shape and color tokens', () {
        final card = theme.cardTheme;

        expect(card.color, tokens.colors.surfaceElevated);
        expect(card.elevation, tokens.shape.cardElevation);
        expect(
          card.shape,
          RoundedRectangleBorder(
            borderRadius: tokens.shape.borderRadiusLg,
            side: tokens.shape.borderSide(tokens.colors.outline),
          ),
        );
      });

      test('list tile and input decoration come from density tokens', () {
        final input = theme.inputDecorationTheme;

        expect(theme.listTileTheme.minTileHeight, tokens.density.rowHeight);
        expect(input.constraints?.minHeight, tokens.density.controlHeight);
        expect(input.fillColor, tokens.colors.surface);
      });
    });
  }

  test('different tokens produce different themes', () {
    expect(_build(sampleTokensA), isNot(_build(sampleTokensB)));
  });

  test('the same tokens produce equal extensions', () {
    expect(
      _build(sampleTokensA).extension<BrandColors>(),
      _build(sampleTokensA).extension<BrandColors>(),
    );
  });

  test('brightness is applied to the color scheme', () {
    final dark = ThemeFactory.build(sampleTokensA, brightness: Brightness.dark);

    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(dark.colorScheme.primary, sampleTokensA.colors.brandPrimary);
  });

  test('ThemeData.lerp interpolates the registered extensions', () {
    final a = _build(sampleTokensA);
    final b = _build(sampleTokensB);

    final mid = ThemeData.lerp(a, b, 0.5);

    expect(
      mid.extension<BrandColors>(),
      sampleColorsA.lerp(sampleColorsB, 0.5),
    );
    expect(mid.extension<BrandShape>(), sampleShapeA.lerp(sampleShapeB, 0.5));
    expect(
      mid.extension<BrandDensity>(),
      sampleDensityA.lerp(sampleDensityB, 0.5),
    );
    expect(
      mid.extension<BrandMotion>(),
      sampleMotionA.lerp(sampleMotionB, 0.5),
    );
  });
}
