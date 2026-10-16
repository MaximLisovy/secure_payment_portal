import 'package:equatable/equatable.dart';
import 'package:flutter/animation.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_colors.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_motion.dart';

/// How the security scan looks and moves for one brand, resolved once from the
/// brand's tokens. The painter reads only this, never `Theme` or `BuildContext`,
/// and no brand is ever named: a new brand gets its own scan from its tokens.
final class ScanStyle extends Equatable {
  const ScanStyle({
    required this.glow,
    required this.track,
    required this.core,
    required this.period,
    required this.pulseCurve,
  });

  factory ScanStyle.from(BrandColors colors, BrandMotion motion) => ScanStyle(
    glow: colors.scanGlow,
    track: colors.outlineSubtle,
    core: colors.brandOnSurface,
    period: periodFor(motion),
    pulseCurve: motion.standard,
  );

  /// One revolution is [periodSlowFactor] times the brand's `slow` duration,
  /// held between [minPeriod] and [maxPeriod]: a crisp brand does not get a
  /// frantic scan, and a fluid one does not drag.
  static const periodSlowFactor = 4;
  static const minPeriod = Duration(milliseconds: 1600);
  static const maxPeriod = Duration(milliseconds: 3000);

  static Duration periodFor(BrandMotion motion) {
    final period = motion.slow * periodSlowFactor;
    if (period < minPeriod) return minPeriod;
    if (period > maxPeriod) return maxPeriod;
    return period;
  }

  /// The sweep and the pulses.
  final Color glow;

  /// The rings, crosshair and ticks behind the animation.
  final Color track;

  /// The dot at the centre.
  final Color core;

  /// Time of one revolution of the sweep, and of one pulse cycle.
  final Duration period;

  /// Shapes how a pulse expands: soft for a fluid brand, quick for a crisp one.
  final Curve pulseCurve;

  @override
  List<Object?> get props => [glow, track, core, period, pulseCurve];
}
