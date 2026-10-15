import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/core/design_system/theme/theme_factory.dart';

final brandRegistryProvider = Provider<BrandRegistry>(
  (ref) => BrandRegistry.standard,
);

/// The brand resolved at startup. Overridden in the root `ProviderScope`.
final initialBrandProvider = Provider<BrandConfig>(
  (ref) => throw UnimplementedError(
    'initialBrandProvider must be overridden in the root ProviderScope.',
  ),
);

final activeBrandProvider = NotifierProvider<ActiveBrandNotifier, BrandConfig>(
  ActiveBrandNotifier.new,
);

class ActiveBrandNotifier extends Notifier<BrandConfig> {
  @override
  BrandConfig build() => ref.watch(initialBrandProvider);

  /// Switches the active brand (demo switcher and tests).
  void select(String id) {
    final brand = ref.read(brandRegistryProvider).byId(id);
    if (brand == null) {
      throw ArgumentError.value(id, 'id', 'is not a registered brand');
    }
    state = brand;
  }
}

/// Rebuilt only when the active brand's tokens change.
final themeProvider = Provider<ThemeData>((ref) {
  final tokens = ref.watch(activeBrandProvider.select((brand) => brand.tokens));
  return ThemeFactory.build(tokens, brightness: Brightness.light);
});
