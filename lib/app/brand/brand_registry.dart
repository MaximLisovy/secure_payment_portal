import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:secure_payment_portal/app/brand/brand_registration.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/brands/utility/utility_brand.dart';
import 'package:secure_payment_portal/features/payment/payment.dart'
    show DemoBill;

/// Thrown when the running flavor cannot be mapped to a registered brand. It is
/// a build/configuration mistake, not a runtime condition, so it fails fast.
class BrandResolutionError extends Error {
  BrandResolutionError(this.message);

  final String message;

  @override
  String toString() => 'BrandResolutionError: $message';
}

/// The only place that maps a flavor id to a [BrandConfig], and the only file
/// that reads `appFlavor`. Adding a brand = one import and one list entry here.
class BrandRegistry {
  const BrandRegistry(this._registrations, {required this.defaultBrandId});

  /// The brands shipped by this app.
  static const standard = BrandRegistry([
    if (!kReleaseMode || appFlavor == 'retail') retailRegistration,
    if (!kReleaseMode || appFlavor == 'utility') utilityRegistration,
  ], defaultBrandId: 'retail');

  final List<BrandRegistration> _registrations;

  /// Used when no flavor is given outside release (`flutter test`, iOS, a run
  /// without `--flavor`).
  final String defaultBrandId;

  Iterable<DemoBill> get demoBills =>
      _registrations.expand((entry) => entry.demoBills);

  Iterable<BrandConfig> get all => _registrations.map((entry) => entry.brand);

  BrandConfig? byId(String id) {
    for (final brand in all) {
      if (brand.id == id) return brand;
    }
    return null;
  }

  /// The host's initial example, used only while no request was selected.
  String demoPaymentIdFor(String brandId) {
    for (final entry in _registrations) {
      if (entry.brand.id == brandId) return entry.demoPaymentId;
    }
    throw BrandResolutionError('No demo payment registered for "$brandId".');
  }

  /// Resolves the brand for [flavor] (the running Android flavor by default).
  ///
  /// An unknown flavor always throws. A missing flavor falls back to
  /// [defaultBrandId] unless [strict] (release builds by default) is set.
  BrandConfig resolve({
    String? flavor = appFlavor,
    bool strict = kReleaseMode,
  }) {
    if (flavor == null) {
      if (strict) {
        throw BrandResolutionError(
          'No flavor set. Build with --flavor <$_registeredIds>.',
        );
      }
      return _requireDefault();
    }
    final brand = byId(flavor);
    if (brand == null) {
      throw BrandResolutionError(
        'Unknown flavor "$flavor". Registered brands: $_registeredIds. '
        'Register it in BrandRegistry.standard.',
      );
    }
    return brand;
  }

  BrandConfig _requireDefault() {
    final brand = byId(defaultBrandId);
    if (brand == null) {
      throw BrandResolutionError(
        'Default brand "$defaultBrandId" is not registered. '
        'Registered brands: $_registeredIds.',
      );
    }
    return brand;
  }

  String get _registeredIds => all.map((b) => b.id).join(' | ');
}
