import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_colors.dart';

/// Maps brand color roles onto a Material [ColorScheme]. Built explicitly, not
/// with `ColorScheme.fromSeed`, so every scheme color is a token and nothing is
/// derived behind the brand's back.
abstract final class ColorSchemeBuilder {
  static ColorScheme build(BrandColors colors, Brightness brightness) {
    return ColorScheme(
      brightness: brightness,
      primary: colors.brandPrimary,
      onPrimary: colors.onBrandPrimary,
      secondary: colors.brandAccent,
      onSecondary: colors.onBrandAccent,
      error: colors.danger,
      onError: colors.onDanger,
      surface: colors.surface,
      onSurface: colors.onSurface,
      onSurfaceVariant: colors.onSurfaceMuted,
      outline: colors.outline,
      outlineVariant: colors.outline,
      surfaceContainerLowest: colors.surface,
      surfaceContainerLow: colors.surfaceElevated,
      surfaceContainer: colors.surfaceElevated,
      surfaceContainerHigh: colors.surfaceElevated,
      surfaceContainerHighest: colors.surfaceElevated,
      // Elevation is expressed by shadow, never by tinting surfaces with the
      // primary color.
      surfaceTint: Colors.transparent,
    );
  }
}
