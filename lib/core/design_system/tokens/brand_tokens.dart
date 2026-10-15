import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_colors.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_density.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_motion.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_shape.dart';

/// Everything visual that differs between brands, split by concern.
/// `ThemeFactory` turns one of these into a `ThemeData`.
class BrandTokens extends Equatable {
  const BrandTokens({
    required this.colors,
    required this.shape,
    required this.density,
    required this.motion,
  });

  final BrandColors colors;
  final BrandShape shape;
  final BrandDensity density;
  final BrandMotion motion;

  /// The extensions to register on `ThemeData`. `ThemeData.extensions` is typed
  /// `ThemeExtension<dynamic>` by the framework.
  Iterable<ThemeExtension<dynamic>> get extensions => <ThemeExtension<dynamic>>[
    colors,
    shape,
    density,
    motion,
  ];

  @override
  List<Object?> get props => [colors, shape, density, motion];
}
