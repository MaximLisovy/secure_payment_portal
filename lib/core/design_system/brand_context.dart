import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_colors.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_density.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_motion.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_shape.dart';

/// Typed access to the brand tokens registered on the ambient `Theme`.
///
/// A missing extension is a bug (the theme was not built by `ThemeFactory`), so
/// it throws in every build mode instead of falling back to a default.
extension BrandThemeContext on BuildContext {
  BrandColors get brandColors => _require<BrandColors>(this);
  BrandShape get brandShape => _require<BrandShape>(this);
  BrandDensity get brandDensity => _require<BrandDensity>(this);
  BrandMotion get brandMotion => _require<BrandMotion>(this);

  /// [duration], or zero when the user asked for reduced motion.
  Duration adaptiveDuration(Duration duration) =>
      MediaQuery.disableAnimationsOf(this) ? Duration.zero : duration;
}

T _require<T extends ThemeExtension<T>>(BuildContext context) {
  final extension = Theme.of(context).extension<T>();
  if (extension == null) {
    throw StateError(
      '$T is not registered on the current ThemeData. '
      'Build the theme with ThemeFactory.build(tokens).',
    );
  }
  return extension;
}
