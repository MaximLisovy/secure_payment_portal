import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_colors.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_density.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_motion.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_shape.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_tokens.dart';

// Two deliberately different token sets, so lerp/copyWith tests do not depend
// on the real brands. Every field differs between A and B.

const sampleColorsA = BrandColors(
  brandPrimary: Color(0xFF000000),
  onBrandPrimary: Color(0xFFFFFFFF),
  brandAccent: Color(0xFF101010),
  onBrandAccent: Color(0xFFF0F0F0),
  brandOnSurface: Color(0xFF181818),
  canvas: Color(0xFF202020),
  surface: Color(0xFF303030),
  surfaceElevated: Color(0xFF404040),
  onSurface: Color(0xFF505050),
  onSurfaceMuted: Color(0xFF606060),
  outline: Color(0xFF707070),
  success: Color(0xFF808080),
  danger: Color(0xFF909090),
  onDanger: Color(0xFFA0A0A0),
  scanGlow: Color(0xFFB0B0B0),
  brandGradient: LinearGradient(colors: [Color(0xFF000000), Color(0xFF101010)]),
);

const sampleColorsB = BrandColors(
  brandPrimary: Color(0xFFFFFFFF),
  onBrandPrimary: Color(0xFF000000),
  brandAccent: Color(0xFFEFEFEF),
  onBrandAccent: Color(0xFF0F0F0F),
  brandOnSurface: Color(0xFFE7E7E7),
  canvas: Color(0xFFDFDFDF),
  surface: Color(0xFFCFCFCF),
  surfaceElevated: Color(0xFFBFBFBF),
  onSurface: Color(0xFFAFAFAF),
  onSurfaceMuted: Color(0xFF9F9F9F),
  outline: Color(0xFF8F8F8F),
  success: Color(0xFF7F7F7F),
  danger: Color(0xFF6F6F6F),
  onDanger: Color(0xFF5F5F5F),
  scanGlow: Color(0xFF4F4F4F),
  brandGradient: LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFEFEFEF)]),
);

const sampleShapeA = BrandShape(
  radiusSm: 0,
  radiusMd: 2,
  radiusLg: 4,
  borderWidth: 1,
  cardElevation: 0,
);

const sampleShapeB = BrandShape(
  radiusSm: 10,
  radiusMd: 20,
  radiusLg: 40,
  borderWidth: 3,
  cardElevation: 8,
);

const sampleDensityA = BrandDensity(
  spaceXs: 2,
  spaceSm: 4,
  spaceMd: 8,
  spaceLg: 12,
  spaceXl: 16,
  visualDensity: VisualDensity.compact,
  rowHeight: 40,
  controlHeight: 36,
);

const sampleDensityB = BrandDensity(
  spaceXs: 6,
  spaceSm: 12,
  spaceMd: 24,
  spaceLg: 36,
  spaceXl: 48,
  visualDensity: VisualDensity.standard,
  rowHeight: 80,
  controlHeight: 60,
);

const sampleMotionA = BrandMotion(
  fast: Duration(milliseconds: 100),
  medium: Duration(milliseconds: 200),
  slow: Duration(milliseconds: 400),
  standard: Curves.linear,
  emphasized: Curves.easeOut,
  pageTransitions: PageTransitionsTheme(
    builders: {TargetPlatform.android: FadeUpwardsPageTransitionsBuilder()},
  ),
);

const sampleMotionB = BrandMotion(
  fast: Duration(milliseconds: 300),
  medium: Duration(milliseconds: 600),
  slow: Duration(milliseconds: 1200),
  standard: Curves.easeInOut,
  emphasized: Curves.bounceOut,
  pageTransitions: PageTransitionsTheme(
    builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()},
  ),
);

const sampleTokensA = BrandTokens(
  colors: sampleColorsA,
  shape: sampleShapeA,
  density: sampleDensityA,
  motion: sampleMotionA,
);

const sampleTokensB = BrandTokens(
  colors: sampleColorsB,
  shape: sampleShapeB,
  density: sampleDensityB,
  motion: sampleMotionB,
);
