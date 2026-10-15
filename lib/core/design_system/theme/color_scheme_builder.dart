import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_colors.dart';

/// Maps brand color roles onto a Material [ColorScheme]. Built explicitly, not
/// with `ColorScheme.fromSeed`, so every scheme color is a token and nothing is
/// derived behind the brand's back.
///
/// Material reads `primary` as a foreground far more often than as a fill (text
/// buttons, switches, checkboxes, sliders, focus, progress), so `primary` is the
/// accessible `brandOnSurface` and widgets nobody themed are readable by default.
/// The vivid `brandPrimary` never goes through the scheme: it is applied
/// explicitly where a fill is intended (`ComponentThemes`: FilledButton, AppBar).
abstract final class ColorSchemeBuilder {
  static ColorScheme build(BrandColors colors, Brightness brightness) {
    return ColorScheme(
      brightness: brightness,
      primary: colors.brandOnSurface,
      // Reads on `brandOnSurface`: that role keeps 4.5:1 against every neutral
      // surface (the contrast table), and contrast is symmetric.
      onPrimary: colors.surface,
      secondary: colors.brandAccent,
      onSecondary: colors.onBrandAccent,
      error: colors.danger,
      onError: colors.onDanger,
      surface: colors.surface,
      onSurface: colors.onSurface,
      onSurfaceVariant: colors.onSurfaceMuted,
      outline: colors.outline,
      outlineVariant: colors.outlineSubtle,
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
