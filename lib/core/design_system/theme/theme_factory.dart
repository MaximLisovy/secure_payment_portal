import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/theme/color_scheme_builder.dart';
import 'package:secure_payment_portal/core/design_system/theme/component_themes.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_tokens.dart';

/// The single place that turns brand tokens into a `ThemeData`. Every brand goes
/// through it, so no brand hand-writes a theme.
///
/// [brightness] is explicit so a dark token set can be added later without
/// touching this class or any widget.
abstract final class ThemeFactory {
  static ThemeData build(BrandTokens tokens, {required Brightness brightness}) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorSchemeBuilder.build(tokens.colors, brightness),
      scaffoldBackgroundColor: tokens.colors.canvas,
      visualDensity: tokens.density.visualDensity,
      pageTransitionsTheme: tokens.motion.pageTransitions,
      appBarTheme: ComponentThemes.appBar(tokens),
      cardTheme: ComponentThemes.card(tokens),
      filledButtonTheme: ComponentThemes.filledButton(tokens),
      outlinedButtonTheme: ComponentThemes.outlinedButton(tokens),
      textButtonTheme: ComponentThemes.textButton(tokens),
      inputDecorationTheme: ComponentThemes.inputDecoration(tokens),
      textSelectionTheme: ComponentThemes.textSelection(tokens),
      listTileTheme: ComponentThemes.listTile(tokens),
      dividerTheme: ComponentThemes.divider(tokens),
      progressIndicatorTheme: ComponentThemes.progressIndicator(tokens),
      snackBarTheme: ComponentThemes.snackBar(tokens),
      extensions: tokens.extensions,
    );
  }
}
