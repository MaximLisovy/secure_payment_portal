import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:secure_payment_portal/app/brand/brand_providers.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';

/// Overrides for the root `ProviderScope`. Each feature's config provider is
/// wired to the active brand here as those features are added.
List<Override> rootOverrides({required BrandConfig initialBrand}) => [
  initialBrandProvider.overrideWithValue(initialBrand),
];

/// Passed as `ProviderScope(retry: ...)`. Riverpod 3 retries failed providers by
/// default, which must never replay a side effect such as starting a payment.
/// Retry is enabled per provider, only for idempotent reads.
Duration? disableProviderRetry(int retryCount, Object error) => null;
