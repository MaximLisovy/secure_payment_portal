import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/app/app.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/app/di/root_overrides.dart';

void main() {
  final brand = BrandRegistry.standard.resolve();
  runApp(
    ProviderScope(
      retry: disableProviderRetry,
      overrides: rootOverrides(initialBrand: brand),
      child: const App(),
    ),
  );
}
