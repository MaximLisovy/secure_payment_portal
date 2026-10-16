import 'package:flutter/material.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_colors.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_density.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_motion.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_shape.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_tokens.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';

/// Utility Pay: navy and slate, sharp, dense, crisp. `controlHeight` is 44 so a
/// button ends up 36 after `VisualDensity.compact` takes 8 off.
const utilityBrand = BrandConfig(
  id: 'utility',
  displayName: 'Utility Pay',
  tokens: BrandTokens(
    colors: BrandColors(
      brandPrimary: Color(0xFF0B2A4A),
      onBrandPrimary: Color(0xFFFFFFFF),
      brandAccent: Color(0xFF475569),
      onBrandAccent: Color(0xFFFFFFFF),
      brandOnSurface: Color(0xFF0B2A4A),
      canvas: Color(0xFFEEF1F5),
      surface: Color(0xFFFFFFFF),
      surfaceElevated: Color(0xFFF8FAFC),
      onSurface: Color(0xFF0F172A),
      onSurfaceMuted: Color(0xFF475569),
      outline: Color(0xFF738299),
      outlineSubtle: Color(0xFF94A3B8),
      success: Color(0xFF15803D),
      danger: Color(0xFFB91C1C),
      onDanger: Color(0xFFFFFFFF),
      scanGlow: Color(0xFF38BDF8),
      brandGradient: LinearGradient(
        colors: [Color(0xFF0B2A4A), Color(0xFF475569)],
      ),
    ),
    shape: BrandShape(
      radiusSm: 0,
      radiusMd: 2,
      radiusLg: 4,
      borderWidth: 1.5,
      cardElevation: 0,
    ),
    density: BrandDensity(
      spaceXs: 2,
      spaceSm: 4,
      spaceMd: 8,
      spaceLg: 12,
      spaceXl: 16,
      visualDensity: VisualDensity.compact,
      rowHeight: 40,
      controlHeight: 44,
    ),
    motion: BrandMotion(
      fast: Duration(milliseconds: 100),
      medium: Duration(milliseconds: 160),
      slow: Duration(milliseconds: 240),
      standard: Curves.easeOut,
      emphasized: Curves.easeOutCubic,
      pageTransitions: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    ),
  ),
  payment: PaymentScreenConfig(sections: [SummarySpec(), BillBreakdownSpec()]),
);
