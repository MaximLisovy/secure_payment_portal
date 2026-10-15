import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/tokens/token_lerp.dart';

/// Semantic color roles of a brand. Names describe the role, never the hue.
class BrandColors extends ThemeExtension<BrandColors> with Equatable {
  const BrandColors({
    required this.brandPrimary,
    required this.onBrandPrimary,
    required this.brandAccent,
    required this.onBrandAccent,
    required this.brandOnSurface,
    required this.canvas,
    required this.surface,
    required this.surfaceElevated,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.outline,
    required this.success,
    required this.danger,
    required this.onDanger,
    required this.scanGlow,
    required this.brandGradient,
  });

  final Color brandPrimary;
  final Color onBrandPrimary;
  final Color brandAccent;
  final Color onBrandAccent;

  /// The brand color as a *foreground* on [canvas] and the surfaces: text and
  /// outlined buttons, icons, the focus ring, progress, the text cursor.
  /// [brandPrimary] is for fills and may be too light to read as a foreground,
  /// so this role must keep 4.5:1 for text and 3:1 for other UI on every
  /// neutral surface (enforced for every brand by the component contrast test).
  final Color brandOnSurface;

  /// Scaffold background, behind every surface.
  final Color canvas;
  final Color surface;
  final Color surfaceElevated;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color outline;
  final Color success;
  final Color danger;
  final Color onDanger;

  /// Glow of the security scanning animation.
  final Color scanGlow;
  final LinearGradient brandGradient;

  @override
  BrandColors copyWith({
    Color? brandPrimary,
    Color? onBrandPrimary,
    Color? brandAccent,
    Color? onBrandAccent,
    Color? brandOnSurface,
    Color? canvas,
    Color? surface,
    Color? surfaceElevated,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? outline,
    Color? success,
    Color? danger,
    Color? onDanger,
    Color? scanGlow,
    LinearGradient? brandGradient,
  }) {
    return BrandColors(
      brandPrimary: brandPrimary ?? this.brandPrimary,
      onBrandPrimary: onBrandPrimary ?? this.onBrandPrimary,
      brandAccent: brandAccent ?? this.brandAccent,
      onBrandAccent: onBrandAccent ?? this.onBrandAccent,
      brandOnSurface: brandOnSurface ?? this.brandOnSurface,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      outline: outline ?? this.outline,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      scanGlow: scanGlow ?? this.scanGlow,
      brandGradient: brandGradient ?? this.brandGradient,
    );
  }

  @override
  BrandColors lerp(BrandColors? other, double t) {
    if (other == null) return this;
    return BrandColors(
      brandPrimary: lerpColor(brandPrimary, other.brandPrimary, t),
      onBrandPrimary: lerpColor(onBrandPrimary, other.onBrandPrimary, t),
      brandAccent: lerpColor(brandAccent, other.brandAccent, t),
      onBrandAccent: lerpColor(onBrandAccent, other.onBrandAccent, t),
      brandOnSurface: lerpColor(brandOnSurface, other.brandOnSurface, t),
      canvas: lerpColor(canvas, other.canvas, t),
      surface: lerpColor(surface, other.surface, t),
      surfaceElevated: lerpColor(surfaceElevated, other.surfaceElevated, t),
      onSurface: lerpColor(onSurface, other.onSurface, t),
      onSurfaceMuted: lerpColor(onSurfaceMuted, other.onSurfaceMuted, t),
      outline: lerpColor(outline, other.outline, t),
      success: lerpColor(success, other.success, t),
      danger: lerpColor(danger, other.danger, t),
      onDanger: lerpColor(onDanger, other.onDanger, t),
      scanGlow: lerpColor(scanGlow, other.scanGlow, t),
      brandGradient: lerpGradient(brandGradient, other.brandGradient, t),
    );
  }

  @override
  List<Object?> get props => [
    brandPrimary,
    onBrandPrimary,
    brandAccent,
    onBrandAccent,
    brandOnSurface,
    canvas,
    surface,
    surfaceElevated,
    onSurface,
    onSurfaceMuted,
    outline,
    success,
    danger,
    onDanger,
    scanGlow,
    brandGradient,
  ];
}
