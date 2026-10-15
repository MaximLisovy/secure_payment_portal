import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/tokens/token_lerp.dart';

/// Durations, curves and page transitions. Retail is fluid, Utility is crisp.
///
/// Durations interpolate. Curves and [pageTransitions] cannot, so during a
/// theme switch they keep the old value until t = 0.5 and then take the new one.
class BrandMotion extends ThemeExtension<BrandMotion> with Equatable {
  const BrandMotion({
    required this.fast,
    required this.medium,
    required this.slow,
    required this.standard,
    required this.emphasized,
    required this.pageTransitions,
  });

  final Duration fast;
  final Duration medium;
  final Duration slow;
  final Curve standard;
  final Curve emphasized;
  final PageTransitionsTheme pageTransitions;

  @override
  BrandMotion copyWith({
    Duration? fast,
    Duration? medium,
    Duration? slow,
    Curve? standard,
    Curve? emphasized,
    PageTransitionsTheme? pageTransitions,
  }) {
    return BrandMotion(
      fast: fast ?? this.fast,
      medium: medium ?? this.medium,
      slow: slow ?? this.slow,
      standard: standard ?? this.standard,
      emphasized: emphasized ?? this.emphasized,
      pageTransitions: pageTransitions ?? this.pageTransitions,
    );
  }

  @override
  BrandMotion lerp(BrandMotion? other, double t) {
    if (other == null) return this;
    return BrandMotion(
      fast: lerpDuration(fast, other.fast, t),
      medium: lerpDuration(medium, other.medium, t),
      slow: lerpDuration(slow, other.slow, t),
      standard: lerpStep(standard, other.standard, t),
      emphasized: lerpStep(emphasized, other.emphasized, t),
      pageTransitions: lerpStep(pageTransitions, other.pageTransitions, t),
    );
  }

  @override
  List<Object?> get props => [
    fast,
    medium,
    slow,
    standard,
    emphasized,
    pageTransitions,
  ];
}
