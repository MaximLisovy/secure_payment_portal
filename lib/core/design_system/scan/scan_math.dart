import 'dart:math' as math;

/// The maths of the security scan: a radar sweep with staggered pulses.
///
/// Everything is a function of one number, `t`, the phase of the animation in
/// [0, 1) (`AnimationController.repeat()` never yields exactly 1). `t` is
/// elapsed time over the period, so the motion is the same at 60 and 120 Hz.
///
/// ```
/// sweep     angle(t)  = -π/2 + 2π·t                  clockwise from 12 o'clock
///           behind the edge by a turns (0 <= a <= 0.25):
///           envelope  = (1 - a / 0.25)²              1 at the edge, 0 at the tail
///
/// pulses    n = 3,  p_i(t) = frac(t + i/3)           progress of ring i, [0, 1)
///           radius_i  = R · clamp(ease(p_i), 0, 1)   ease = the brand's curve
///           envelope  = (1 - p_i)² · smoothstep(0, 0.12, p_i)    (alpha = 0.8 · envelope)
///           stroke_i  = w · (1 - 0.5·p_i)
/// ```
///
/// **Period and units.** One revolution and one pulse cycle both last one
/// period, `ScanStyle.period`. Angles are radians, radii are fractions of the
/// scan radius `R`, envelopes are fractions of the peak alpha of their layer.
///
/// **Why it repeats without a seam.** The sweep angle differs by exactly 2π
/// between t = 0 and t = 1, so the picture is identical. A pulse jumps from
/// radius R back to radius 0 at the wrap, and its envelope is 0 on both sides
/// of that jump (the `(1 - p)²` factor at p → 1, the fade-in at p = 0), so the
/// jump is never seen. The sweep turns at a constant speed (a radar does not
/// ease); the brand's curve shapes how the pulses expand.
abstract final class ScanMath {
  /// Rings in flight at once, spaced 1/[pulseCount] of a period apart.
  static const pulseCount = 3;

  /// Length of the sweep's glowing tail, in turns.
  static const sweepTail = 0.25;

  /// Alpha of the sweep at its leading edge and of a pulse at its brightest.
  static const sweepPeakAlpha = 0.6;
  static const pulsePeakAlpha = 0.8;

  /// Share of its life a pulse spends fading in, so it never pops into view.
  static const pulseFadeIn = 0.12;

  /// The phase shown when motion is reduced: the sweep has a visible wedge and
  /// the three rings are at different radii.
  static const restPhase = 0.125;

  /// Distinct alpha steps a pulse can take. The painter keeps one prepared
  /// colour per step, so drawing allocates no `Color`.
  static const alphaLevels = 32;

  static const _startAngle = -math.pi / 2;
  static const _sweepSteps = 5;

  /// The fractional part of [x], in [0, 1), for negative [x] too.
  static double frac(double x) => x - x.floorToDouble();

  static double smoothstep(double edge0, double edge1, double x) {
    if (x <= edge0) return 0;
    if (x >= edge1) return 1;
    final u = (x - edge0) / (edge1 - edge0);
    return u * u * (3 - 2 * u);
  }

  /// Angle of the sweep's leading edge at phase [t], in radians.
  static double sweepAngle(double t) => _startAngle + 2 * math.pi * t;

  /// Envelope of the sweep [turnsBehind] the leading edge.
  static double sweepEnvelope(double turnsBehind) {
    if (turnsBehind < 0 || turnsBehind >= sweepTail) return 0;
    final left = 1 - turnsBehind / sweepTail;
    return left * left;
  }

  /// Stops of the sweep gradient over one full turn, where the leading edge sits
  /// at 1: nothing until the tail starts, then [_sweepSteps] steps up to the edge.
  static final List<double> sweepStops = List.unmodifiable(<double>[
    0,
    for (var k = 0; k <= _sweepSteps; k++)
      1 - sweepTail + sweepTail * k / _sweepSteps,
  ]);

  /// The envelope at each of [sweepStops].
  static final List<double> sweepEnvelopes = List.unmodifiable(<double>[
    0,
    for (var k = 0; k <= _sweepSteps; k++)
      sweepEnvelope(sweepTail * (1 - k / _sweepSteps)),
  ]);

  /// Progress of pulse [index] at phase [t]: 0 when it is born, then up to 1.
  static double pulseProgress(double t, int index) =>
      frac(t + index / pulseCount);

  /// How far out the pulse is, as a fraction of the scan radius. [ease] is the
  /// brand's curve; a curve that overshoots is held inside the scan.
  static double pulseRadiusFraction(
    double progress,
    double Function(double) ease,
  ) => math.min(1.0, math.max(0.0, ease(progress)));

  /// How visible the pulse is, in [0, 1]: 0 when born and when spent.
  static double pulseEnvelope(double progress) {
    final left = 1 - progress;
    return left * left * smoothstep(0, pulseFadeIn, progress);
  }

  /// Stroke width of the pulse relative to the base width: thins as it expands.
  static double pulseStrokeScale(double progress) => 1 - 0.5 * progress;

  /// The alpha step of an [envelope] in [0, 1], in [0, alphaLevels].
  static int alphaLevel(double envelope) =>
      math.min(alphaLevels, math.max(0, (envelope * alphaLevels).round()));
}
