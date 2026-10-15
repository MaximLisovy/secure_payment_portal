import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_colors.dart';

import 'contrast.dart';

/// WCAG 2.x minimums: 4.5:1 for text, 3:1 for the UI that identifies or
/// operates a component (borders, focus ring, icons, progress, cursor).
enum ContrastKind {
  text(4.5),
  ui(3);

  const ContrastKind(this.minRatio);

  final double minRatio;
}

typedef ThemeColor = Color Function(ThemeData theme);

/// One foreground drawn on one or more backgrounds.
class ContrastPair {
  const ContrastPair({
    required this.name,
    required this.kind,
    required this.foreground,
    this.backgrounds = _neutralSurfaces,
  });

  final String name;
  final ContrastKind kind;
  final ThemeColor foreground;

  /// Backgrounds the foreground can sit on, by name. Defaults to every neutral
  /// surface of the brand.
  final Map<String, ThemeColor> backgrounds;
}

class ContrastFailure {
  const ContrastFailure(this.pair, this.background, this.ratio, this.kind);

  final String pair;
  final String background;
  final double ratio;
  final ContrastKind kind;

  @override
  String toString() =>
      '$pair on $background: ${ratio.toStringAsFixed(2)}:1, '
      'needs ${kind.minRatio}:1 (${kind.name})';
}

const _enabled = <WidgetState>{};

// Read from the theme, so a missing value fails loudly instead of the pair
// being silently skipped or Material's "primary" default being assumed.
T _need<T>(T? value, String what) {
  if (value == null) throw StateError('$what is not set by the theme');
  return value;
}

const Map<String, ThemeColor> _neutralSurfaces = {
  'canvas': _canvas,
  'surface': _surface,
  'elevated surface': _elevatedSurface,
};

Color _canvas(ThemeData t) => t.scaffoldBackgroundColor;
Color _surface(ThemeData t) => t.colorScheme.surface;
Color _elevatedSurface(ThemeData t) =>
    _need(t.cardTheme.color, 'cardTheme.color');

BrandColors _brandColors(ThemeData t) =>
    _need(t.extension<BrandColors>(), 'the BrandColors extension');

Color _gradientStart(ThemeData t) => _brandColors(t).brandGradient.colors.first;
Color _gradientEnd(ThemeData t) => _brandColors(t).brandGradient.colors.last;

Color _foreground(ButtonStyle? style, String what) =>
    _need(style?.foregroundColor?.resolve(_enabled), what);

Color _background(ButtonStyle? style, String what) =>
    _need(style?.backgroundColor?.resolve(_enabled), what);

Color _outlinedSide(ThemeData t) => _need(
  t.outlinedButtonTheme.style?.side?.resolve(_enabled)?.color,
  'outlinedButtonTheme side',
);

/// Every foreground/background pair that `ComponentThemes` and `ThemeFactory`
/// actually put on screen. Add a row here whenever a component color is added.
///
/// Deliberately not listed, because WCAG 1.4.11 exempts them: disabled states,
/// logos, and purely decorative edges, which use the soft `outlineSubtle` role
/// (card border, divider, progress track). The control edges that must be seen
/// (input border, outlined button) use `outline` and are listed. If a control
/// ever picks up `outlineSubtle`, its row here fails.
final List<ContrastPair> componentContrastPairs = [
  // --- Text: 4.5:1 ---
  ContrastPair(
    name: 'body text',
    kind: ContrastKind.text,
    foreground: (t) => t.colorScheme.onSurface,
  ),
  ContrastPair(
    name: 'list tile title',
    kind: ContrastKind.text,
    foreground: (t) => _need(t.listTileTheme.textColor, 'listTileTheme text'),
  ),
  ContrastPair(
    name: 'input label',
    kind: ContrastKind.text,
    foreground: (t) =>
        _need(t.inputDecorationTheme.labelStyle?.color, 'input label'),
  ),
  ContrastPair(
    name: 'input hint',
    kind: ContrastKind.text,
    foreground: (t) =>
        _need(t.inputDecorationTheme.hintStyle?.color, 'input hint'),
  ),
  ContrastPair(
    name: 'error text',
    kind: ContrastKind.text,
    foreground: (t) => t.colorScheme.error,
  ),
  ContrastPair(
    name: 'text button label',
    kind: ContrastKind.text,
    foreground: (t) =>
        _foreground(t.textButtonTheme.style, 'textButtonTheme foreground'),
  ),
  ContrastPair(
    name: 'outlined button label',
    kind: ContrastKind.text,
    foreground: (t) => _foreground(
      t.outlinedButtonTheme.style,
      'outlinedButtonTheme foreground',
    ),
  ),
  ContrastPair(
    name: 'filled button label',
    kind: ContrastKind.text,
    foreground: (t) =>
        _foreground(t.filledButtonTheme.style, 'filledButtonTheme foreground'),
    backgrounds: {
      'filled button': (t) =>
          _background(t.filledButtonTheme.style, 'filledButtonTheme fill'),
    },
  ),
  ContrastPair(
    name: 'app bar title and icons',
    kind: ContrastKind.text,
    foreground: (t) =>
        _need(t.appBarTheme.foregroundColor, 'appBarTheme foreground'),
    backgrounds: {
      'app bar': (t) =>
          _need(t.appBarTheme.backgroundColor, 'appBarTheme background'),
    },
  ),
  ContrastPair(
    name: 'snackbar text',
    kind: ContrastKind.text,
    foreground: (t) => _need(
      t.snackBarTheme.contentTextStyle?.color,
      'snackBarTheme content text',
    ),
    backgrounds: {
      'snackbar': (t) =>
          _need(t.snackBarTheme.backgroundColor, 'snackBarTheme background'),
    },
  ),
  ContrastPair(
    name: 'snackbar action',
    kind: ContrastKind.text,
    foreground: (t) =>
        _need(t.snackBarTheme.actionTextColor, 'snackBarTheme action'),
    backgrounds: {
      'snackbar': (t) =>
          _need(t.snackBarTheme.backgroundColor, 'snackBarTheme background'),
    },
  ),

  // --- Non-text UI: 3:1 ---
  const ContrastPair(
    name: 'outlined button border',
    kind: ContrastKind.ui,
    foreground: _outlinedSide,
  ),
  ContrastPair(
    name: 'input border',
    kind: ContrastKind.ui,
    foreground: (t) => _need(
      t.inputDecorationTheme.enabledBorder?.borderSide.color,
      'input enabled border',
    ),
  ),
  ContrastPair(
    name: 'input focus ring',
    kind: ContrastKind.ui,
    foreground: (t) => _need(
      t.inputDecorationTheme.focusedBorder?.borderSide.color,
      'input focused border',
    ),
  ),
  ContrastPair(
    name: 'input error border',
    kind: ContrastKind.ui,
    foreground: (t) => _need(
      t.inputDecorationTheme.errorBorder?.borderSide.color,
      'input error border',
    ),
  ),
  ContrastPair(
    name: 'list tile icon',
    kind: ContrastKind.ui,
    foreground: (t) => _need(t.listTileTheme.iconColor, 'listTileTheme icon'),
  ),
  ContrastPair(
    name: 'progress indicator',
    kind: ContrastKind.ui,
    foreground: (t) =>
        _need(t.progressIndicatorTheme.color, 'progressIndicatorTheme color'),
  ),
  ContrastPair(
    name: 'text cursor and selection handles',
    kind: ContrastKind.ui,
    foreground: (t) =>
        _need(t.textSelectionTheme.cursorColor, 'textSelectionTheme cursor'),
  ),

  // --- Colors the payment screen takes from BrandColors directly. ---
  // Success and danger are only ever icons, never text: Utility's success green
  // is 4.4:1 on its canvas, enough for UI but not for body text.
  ContrastPair(
    name: 'secondary text (reference, taxes, hints)',
    kind: ContrastKind.text,
    foreground: (t) => _brandColors(t).onSurfaceMuted,
  ),
  ContrastPair(
    name: 'success icon',
    kind: ContrastKind.ui,
    foreground: (t) => _brandColors(t).success,
  ),
  ContrastPair(
    name: 'danger icon',
    kind: ContrastKind.ui,
    foreground: (t) => _brandColors(t).danger,
  ),
  // Checked at both ends of the gradient; a two-stop gradient is monotone in
  // between. A brand with a three-stop gradient needs a row for the middle.
  ContrastPair(
    name: 'promo banner text on the brand gradient',
    kind: ContrastKind.text,
    foreground: (t) => _brandColors(t).onBrandPrimary,
    backgrounds: {
      'gradient start': _gradientStart,
      'gradient end': _gradientEnd,
    },
  ),

  // --- ColorScheme defaults, read by every widget nobody themed (switch,
  // checkbox, radio, slider, chips, badges...). Not set by ComponentThemes, so
  // these rows are what keeps those widgets readable. ---
  ContrastPair(
    name: 'default primary (switch, checkbox, slider, focus)',
    kind: ContrastKind.text,
    foreground: (t) => t.colorScheme.primary,
  ),
  ContrastPair(
    name: 'label on default primary fill (switch thumb, checkbox mark)',
    kind: ContrastKind.text,
    foreground: (t) => t.colorScheme.onPrimary,
    backgrounds: {'primary fill': (t) => t.colorScheme.primary},
  ),
  ContrastPair(
    name: 'default muted text (onSurfaceVariant)',
    kind: ContrastKind.text,
    foreground: (t) => t.colorScheme.onSurfaceVariant,
  ),
  ContrastPair(
    name: 'default outline (unselected switch, checkbox, radio)',
    kind: ContrastKind.ui,
    foreground: (t) => t.colorScheme.outline,
  ),
  ContrastPair(
    name: 'label on accent fill (chip, badge)',
    kind: ContrastKind.text,
    foreground: (t) => t.colorScheme.onSecondary,
    backgrounds: {'accent fill': (t) => t.colorScheme.secondary},
  ),
  ContrastPair(
    name: 'label on error fill',
    kind: ContrastKind.text,
    foreground: (t) => t.colorScheme.onError,
    backgrounds: {'error fill': (t) => t.colorScheme.error},
  ),
];

/// Every pair of [componentContrastPairs] that is below its minimum on [theme].
/// Throws a [StateError] if a component stopped setting a color the table reads.
List<ContrastFailure> contrastFailures(ThemeData theme) {
  final failures = <ContrastFailure>[];
  for (final pair in componentContrastPairs) {
    final foreground = pair.foreground(theme);
    for (final MapEntry(key: name, value: background)
        in pair.backgrounds.entries) {
      final ratio = contrastRatio(background(theme), foreground);
      if (ratio < pair.kind.minRatio) {
        failures.add(ContrastFailure(pair.name, name, ratio, pair.kind));
      }
    }
  }
  return failures;
}
