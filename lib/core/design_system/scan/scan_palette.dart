import 'package:flutter/painting.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_math.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_style.dart';

/// Every colour the scan paints with, built once per style, so drawing a frame
/// allocates no `Color`: a pulse picks the prepared colour for its alpha step.
final class ScanPalette {
  ScanPalette(ScanStyle style)
    : pulse = _steps(style.glow, ScanMath.pulsePeakAlpha),
      underlay = _steps(style.glow, ScanMath.pulsePeakAlpha * _underlayShare),
      sweep = List.unmodifiable(<Color>[
        for (final envelope in ScanMath.sweepEnvelopes)
          style.glow.withValues(alpha: ScanMath.sweepPeakAlpha * envelope),
      ]),
      edge = style.glow.withValues(alpha: _edgeAlpha);

  /// The wide, faint stroke under a pulse that stands in for a blurred glow.
  static const _underlayShare = 0.25;
  static const _edgeAlpha = 0.9;

  /// A pulse's colour at each alpha step, 0 (clear) to [ScanMath.alphaLevels].
  final List<Color> pulse;

  /// The glow under a pulse, at the same steps.
  final List<Color> underlay;

  /// The colours of the sweep gradient, one per [ScanMath.sweepStops].
  final List<Color> sweep;

  /// The bright line at the sweep's leading edge.
  final Color edge;

  static List<Color> _steps(Color color, double peakAlpha) =>
      List.unmodifiable(<Color>[
        for (var level = 0; level <= ScanMath.alphaLevels; level++)
          color.withValues(alpha: peakAlpha * level / ScanMath.alphaLevels),
      ]);
}
