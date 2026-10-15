import 'package:flutter/material.dart';

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
Color _need(Color? color, String what) {
  if (color == null) throw StateError('$what is not set by the theme');
  return color;
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
/// Deliberately not listed (WCAG exempts them): disabled states, decorative
/// edges (card border, divider, progress track) and logos.
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
