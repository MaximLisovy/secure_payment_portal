import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/tokens/token_lerp.dart';

/// Corner radii, border and elevation. Stored as plain numbers (not
/// `ShapeBorder`s) so a theme switch can always interpolate them.
class BrandShape extends ThemeExtension<BrandShape> with Equatable {
  const BrandShape({
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.borderWidth,
    required this.cardElevation,
  });

  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double borderWidth;
  final double cardElevation;

  BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);

  /// A border of this brand's width in [color].
  BorderSide borderSide(Color color) =>
      BorderSide(color: color, width: borderWidth);

  @override
  BrandShape copyWith({
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? borderWidth,
    double? cardElevation,
  }) {
    return BrandShape(
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      borderWidth: borderWidth ?? this.borderWidth,
      cardElevation: cardElevation ?? this.cardElevation,
    );
  }

  @override
  BrandShape lerp(BrandShape? other, double t) {
    if (other == null) return this;
    return BrandShape(
      radiusSm: lerpValue(radiusSm, other.radiusSm, t),
      radiusMd: lerpValue(radiusMd, other.radiusMd, t),
      radiusLg: lerpValue(radiusLg, other.radiusLg, t),
      borderWidth: lerpValue(borderWidth, other.borderWidth, t),
      cardElevation: lerpValue(cardElevation, other.cardElevation, t),
    );
  }

  @override
  List<Object?> get props => [
    radiusSm,
    radiusMd,
    radiusLg,
    borderWidth,
    cardElevation,
  ];
}
