import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_tokens.dart';

/// Material component themes whose every value comes from [BrandTokens], so
/// plain Material widgets are on-brand without per-widget styling.
///
/// Fills use the vivid `brandPrimary` and are always set explicitly here, because
/// `ColorScheme.primary` is the accessible `brandOnSurface`. Foregrounds are also
/// set explicitly even though the scheme would supply the same color, so the
/// contrast table in `test/helpers/component_contrast_table.dart` reads real
/// values. Any color added here needs a row there.
abstract final class ComponentThemes {
  static AppBarThemeData appBar(BrandTokens t) {
    return AppBarThemeData(
      backgroundColor: t.colors.brandPrimary,
      foregroundColor: t.colors.onBrandPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: t.density.spaceMd,
      toolbarHeight: t.density.controlHeight + t.density.spaceMd,
    );
  }

  static CardThemeData card(BrandTokens t) {
    return CardThemeData(
      color: t.colors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      elevation: t.shape.cardElevation,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: t.shape.borderRadiusLg,
        // Decorative edge: the soft role, exempt from the 3:1 rule.
        side: t.shape.borderSide(t.colors.outlineSubtle),
      ),
    );
  }

  static FilledButtonThemeData filledButton(BrandTokens t) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.colors.brandPrimary,
        foregroundColor: t.colors.onBrandPrimary,
        minimumSize: _minimumButtonSize(t),
        padding: _buttonPadding(t),
        shape: _buttonShape(t),
        animationDuration: t.motion.fast,
      ),
    );
  }

  static OutlinedButtonThemeData outlinedButton(BrandTokens t) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.colors.brandOnSurface,
        minimumSize: _minimumButtonSize(t),
        padding: _buttonPadding(t),
        shape: _buttonShape(t),
        side: t.shape.borderSide(t.colors.brandOnSurface),
        animationDuration: t.motion.fast,
      ),
    );
  }

  static TextButtonThemeData textButton(BrandTokens t) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.colors.brandOnSurface,
        minimumSize: _minimumButtonSize(t),
        padding: _buttonPadding(t),
        shape: _buttonShape(t),
        animationDuration: t.motion.fast,
      ),
    );
  }

  static InputDecorationThemeData inputDecoration(BrandTokens t) {
    OutlineInputBorder border(Color color, {double widthFactor = 1}) {
      return OutlineInputBorder(
        borderRadius: t.shape.borderRadiusMd,
        borderSide: BorderSide(
          color: color,
          width: t.shape.borderWidth * widthFactor,
        ),
      );
    }

    return InputDecorationThemeData(
      filled: true,
      fillColor: t.colors.surface,
      constraints: BoxConstraints(minHeight: t.density.controlHeight),
      contentPadding: EdgeInsets.symmetric(
        horizontal: t.density.spaceMd,
        vertical: t.density.spaceSm + t.density.spaceXs,
      ),
      labelStyle: TextStyle(color: t.colors.onSurfaceMuted),
      hintStyle: TextStyle(color: t.colors.onSurfaceMuted),
      border: border(t.colors.outline),
      enabledBorder: border(t.colors.outline),
      // The focus ring is twice as thick as the resting border.
      focusedBorder: border(t.colors.brandOnSurface, widthFactor: 2),
      errorBorder: border(t.colors.danger),
      focusedErrorBorder: border(t.colors.danger, widthFactor: 2),
    );
  }

  static TextSelectionThemeData textSelection(BrandTokens t) {
    return TextSelectionThemeData(
      cursorColor: t.colors.brandOnSurface,
      selectionHandleColor: t.colors.brandOnSurface,
    );
  }

  static ListTileThemeData listTile(BrandTokens t) {
    return ListTileThemeData(
      minTileHeight: t.density.rowHeight,
      minVerticalPadding: t.density.spaceSm,
      contentPadding: EdgeInsets.symmetric(horizontal: t.density.spaceMd),
      textColor: t.colors.onSurface,
      iconColor: t.colors.brandOnSurface,
    );
  }

  static DividerThemeData divider(BrandTokens t) {
    return DividerThemeData(
      color: t.colors.outlineSubtle,
      thickness: t.shape.borderWidth,
      space: t.density.spaceMd,
    );
  }

  static ProgressIndicatorThemeData progressIndicator(BrandTokens t) {
    return ProgressIndicatorThemeData(
      color: t.colors.brandOnSurface,
      linearTrackColor: t.colors.outlineSubtle,
      linearMinHeight: t.density.spaceSm,
    );
  }

  static SnackBarThemeData snackBar(BrandTokens t) {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.colors.onSurface,
      contentTextStyle: TextStyle(color: t.colors.surface),
      // The action reuses the text color: no brand accent reads on every
      // brand's dark snackbar (Utility's slate accent does not).
      actionTextColor: t.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: t.shape.borderRadiusSm),
    );
  }

  static Size _minimumButtonSize(BrandTokens t) =>
      Size.square(t.density.controlHeight);

  static EdgeInsets _buttonPadding(BrandTokens t) =>
      EdgeInsets.symmetric(horizontal: t.density.spaceLg);

  static OutlinedBorder _buttonShape(BrandTokens t) =>
      RoundedRectangleBorder(borderRadius: t.shape.borderRadiusMd);
}
