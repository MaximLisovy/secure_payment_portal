import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/tokens/token_lerp.dart';

/// Spacing scale and control sizes. A dense brand shrinks the numbers; widgets
/// never hard-code spacing.
class BrandDensity extends ThemeExtension<BrandDensity> with Equatable {
  const BrandDensity({
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
    required this.visualDensity,
    required this.rowHeight,
    required this.controlHeight,
  });

  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;
  final VisualDensity visualDensity;

  /// Minimum height of a list row.
  final double rowHeight;

  /// Minimum height of buttons and text fields, before [visualDensity] adjusts
  /// it (`VisualDensity.compact` takes 8 off a button).
  final double controlHeight;

  @override
  BrandDensity copyWith({
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    VisualDensity? visualDensity,
    double? rowHeight,
    double? controlHeight,
  }) {
    return BrandDensity(
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      visualDensity: visualDensity ?? this.visualDensity,
      rowHeight: rowHeight ?? this.rowHeight,
      controlHeight: controlHeight ?? this.controlHeight,
    );
  }

  @override
  BrandDensity lerp(BrandDensity? other, double t) {
    if (other == null) return this;
    return BrandDensity(
      spaceXs: lerpValue(spaceXs, other.spaceXs, t),
      spaceSm: lerpValue(spaceSm, other.spaceSm, t),
      spaceMd: lerpValue(spaceMd, other.spaceMd, t),
      spaceLg: lerpValue(spaceLg, other.spaceLg, t),
      spaceXl: lerpValue(spaceXl, other.spaceXl, t),
      visualDensity: VisualDensity.lerp(visualDensity, other.visualDensity, t),
      rowHeight: lerpValue(rowHeight, other.rowHeight, t),
      controlHeight: lerpValue(controlHeight, other.controlHeight, t),
    );
  }

  @override
  List<Object?> get props => [
    spaceXs,
    spaceSm,
    spaceMd,
    spaceLg,
    spaceXl,
    visualDensity,
    rowHeight,
    controlHeight,
  ];
}
