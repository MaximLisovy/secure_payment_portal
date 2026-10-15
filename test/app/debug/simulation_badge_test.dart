import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/debug/simulation_badge.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/di/payment_data_source_providers.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';

import '../../helpers/pump_app.dart';

Future<ProviderContainer> _pumpBadge(
  WidgetTester tester, {
  bool realSecurity = false,
  bool realPayment = false,
}) {
  return tester.pumpApp(
    const Scaffold(body: SimulationBadge()),
    brand: retailBrand,
    overrides: [
      realSecurityPlatformDataSourceProvider.overrideWithValue(
        realSecurity ? FakeSecurityPlatformDataSource() : null,
      ),
      if (realPayment)
        realPaymentPlatformDataSourceProvider.overrideWithValue(
          FakePaymentPlatformDataSource(),
        ),
    ],
  );
}

void main() {
  testWidgets('is shown while any source is simulated', (tester) async {
    await _pumpBadge(tester, realSecurity: true);

    expect(find.text(AppStrings.simulatedBadge), findsOneWidget);
  });

  testWidgets('is shown when everything is simulated', (tester) async {
    await _pumpBadge(tester);

    expect(find.text(AppStrings.simulatedBadge), findsOneWidget);
  });

  testWidgets('is hidden when every source is real', (tester) async {
    await _pumpBadge(tester, realSecurity: true, realPayment: true);

    expect(find.text(AppStrings.simulatedBadge), findsNothing);
  });

  testWidgets('appears the moment a source is switched to the simulation', (
    tester,
  ) async {
    final container = await _pumpBadge(
      tester,
      realSecurity: true,
      realPayment: true,
    );
    expect(find.text(AppStrings.simulatedBadge), findsNothing);

    container
        .read(paymentSourceModeProvider.notifier)
        .select(SourceMode.simulated);
    await tester.pump();
    expect(find.text(AppStrings.simulatedBadge), findsOneWidget);

    container.read(paymentSourceModeProvider.notifier).select(SourceMode.real);
    await tester.pump();
    expect(find.text(AppStrings.simulatedBadge), findsNothing);
  });

  testWidgets('says in words that the app is not running for real', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpBadge(tester);

    expect(
      find.bySemanticsLabel(
        RegExp(RegExp.escape(AppStrings.simulatedBadgeHint)),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
