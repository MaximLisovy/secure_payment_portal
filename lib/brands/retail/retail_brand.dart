import 'package:flutter/material.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_colors.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_density.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_motion.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_shape.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_tokens.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';

/// Retail Shop: warm, rounded, fluid.
///
/// The vivid orange (`brandPrimary`) is for fills only, with dark text on it,
/// because white on it fails WCAG AA. As a foreground on cream it is 2.6:1, so
/// text, outlines and icons use the deeper `brandOnSurface`.
const retailBrand = BrandConfig(
  id: 'retail',
  displayName: 'Retail Shop',
  tokens: BrandTokens(
    colors: BrandColors(
      brandPrimary: Color(0xFFF57C00),
      onBrandPrimary: Color(0xFF231403),
      brandAccent: Color(0xFFFFC107),
      onBrandAccent: Color(0xFF231403),
      brandOnSurface: Color(0xFFC2410C),
      canvas: Color(0xFFFFF6E9),
      surface: Color(0xFFFFFBF5),
      surfaceElevated: Color(0xFFFFFFFF),
      onSurface: Color(0xFF2B1A0A),
      onSurfaceMuted: Color(0xFF7A6652),
      outline: Color(0xFF94806A),
      outlineSubtle: Color(0xFFEBD9C3),
      success: Color(0xFF2E7D32),
      danger: Color(0xFFC62828),
      onDanger: Color(0xFFFFFFFF),
      scanGlow: Color(0xFFFFB020),
      brandGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF57C00), Color(0xFFFFC107)],
      ),
    ),
    shape: BrandShape(
      radiusSm: 12,
      radiusMd: 20,
      radiusLg: 28,
      borderWidth: 1,
      cardElevation: 4,
    ),
    density: BrandDensity(
      spaceXs: 4,
      spaceSm: 8,
      spaceMd: 16,
      spaceLg: 24,
      spaceXl: 32,
      visualDensity: VisualDensity.standard,
      rowHeight: 64,
      controlHeight: 52,
    ),
    motion: BrandMotion(
      fast: Duration(milliseconds: 200),
      medium: Duration(milliseconds: 360),
      slow: Duration(milliseconds: 600),
      standard: Curves.easeInOutCubic,
      emphasized: Curves.fastLinearToSlowEaseIn,
      pageTransitions: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    ),
  ),
  payment: PaymentScreenConfig(
    sections: [
      SummarySpec(),
      PromoBannerSpec(
        headline: 'Welcome offer',
        body: 'WELCOME10 is applied: 10% off your first order.',
      ),
    ],
  ),
);
