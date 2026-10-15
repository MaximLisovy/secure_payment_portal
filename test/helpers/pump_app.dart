import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_providers.dart';
import 'package:secure_payment_portal/app/di/root_overrides.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';

extension PumpApp on WidgetTester {
  /// Pumps [home] under the real root providers, themed by [brand] through the
  /// same `themeProvider` the app uses. Returns the scope's container so tests
  /// can drive providers (e.g. switch the active brand).
  Future<ProviderContainer> pumpApp(
    Widget home, {
    required BrandConfig brand,
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        retry: disableProviderRetry,
        overrides: [
          ...rootOverrides(initialBrand: brand),
          ...overrides,
        ],
        child: Consumer(
          builder: (context, ref, _) =>
              MaterialApp(theme: ref.watch(themeProvider), home: home),
        ),
      ),
    );
    return ProviderScope.containerOf(element(find.byType(MaterialApp)));
  }
}
