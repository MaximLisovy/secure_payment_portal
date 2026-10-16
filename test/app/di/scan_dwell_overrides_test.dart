import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_providers.dart';
import 'package:secure_payment_portal/app/di/root_overrides.dart';
import 'package:secure_payment_portal/app/di/scan_dwell_overrides.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/brands/utility/utility_brand.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_animation.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_style.dart';
import 'package:secure_payment_portal/core/design_system/scan/security_scan_painter.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/pay_action_bar.dart';

import '../../features/payment/helpers/payment_ui_harness.dart';
import '../../helpers/pump_app.dart';

ProviderContainer _container(BrandConfig brand) => ProviderContainer.test(
  overrides: [
    ...rootOverrides(initialBrand: brand),
    ...scanDwellOverrides(),
  ],
);

Finder get _payButton => find.descendant(
  of: find.byType(PayActionBar),
  matching: find.byType(FilledButton),
);

bool _payEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_payButton).onPressed != null;

double _sweepPhase(WidgetTester tester) {
  final painter = tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(ScanAnimation),
          matching: find.byType(CustomPaint),
        ),
      )
      .map((paint) => paint.painter)
      .whereType<SecurityScanPainter>()
      .single;
  return painter.animation.value;
}

void main() {
  group('the dwell the app uses', () {
    testWidgets('is one revolution of the active brand scan', (tester) async {
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final container = _container(retailBrand);
      expect(
        container.read(scanDwellProvider),
        const Duration(milliseconds: 2400),
      );
      container.read(activeBrandProvider.notifier).select('utility');
      expect(container.read(scanDwellProvider), ScanStyle.minPeriod);
      await tester.pumpAndSettle(); // Riverpod's refresh timers.
    });

    testWidgets('is none for a user who reduces motion', (tester) async {
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final container = _container(retailBrand);
      container.listen(scanDwellProvider, (_, _) {});

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      expect(container.read(scanDwellProvider), Duration.zero);

      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      expect(
        container.read(scanDwellProvider),
        const Duration(milliseconds: 2400),
      );
      await tester.pumpAndSettle(); // Riverpod's refresh timers.
    });

    test('is not in the root overrides, which tests use as they are', () {
      final container = ProviderContainer.test(
        overrides: rootOverrides(initialBrand: retailBrand),
      );
      expect(container.read(scanDwellProvider), Duration.zero);
    });
  });

  test('the app is started with it', () {
    // main() is the one place a real run is assembled; a build that forgets
    // this line would show the verdict at once and never the full sweep.
    expect(
      File('lib/main.dart').readAsStringSync(),
      contains('scanDwellOverrides()'),
    );
  });

  group('on the payment page', () {
    for (final brand in [retailBrand, utilityBrand]) {
      testWidgets(
        '${brand.id}: Pay waits for the sweep to go all the way round',
        (tester) async {
          final period = ScanStyle.periodFor(brand.tokens.motion);
          await tester.pumpApp(
            const PaymentConfirmationPage(title: 'Test'),
            brand: brand,
            overrides: [...instantBackend(), ...scanDwellOverrides()],
          );
          for (var i = 0; i < 4; i++) {
            await tester.pump();
          }
          expect(find.text(AppStrings.securityChecking), findsOneWidget);
          expect(_payEnabled(tester), isFalse);

          await tester.pump(period - const Duration(milliseconds: 50));
          expect(find.text(AppStrings.securityChecking), findsOneWidget);
          expect(_payEnabled(tester), isFalse, reason: 'not before the end');

          await tester.pump(const Duration(milliseconds: 50));
          expect(_payEnabled(tester), isTrue);
          // The sweep is back at the top, where it started.
          final phase = _sweepPhase(tester);
          expect(math.min(phase, 1 - phase), lessThan(0.03));

          await tester.pumpAndSettle();
          expect(find.text(AppStrings.securityVerified), findsOneWidget);
          expect(find.byType(ScanAnimation), findsNothing);
          await tester.unmountApp();
        },
      );
    }

    testWidgets('with reduced motion Pay is ready at once', (tester) async {
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpApp(
        const PaymentConfirmationPage(title: 'Test'),
        brand: retailBrand,
        overrides: [...instantBackend(), ...scanDwellOverrides()],
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(_payEnabled(tester), isTrue);
      await tester.unmountApp();
    });

    testWidgets('without the override the verdict is not held', (tester) async {
      await tester.pumpPaymentPage(brand: retailBrand);
      expect(_payEnabled(tester), isTrue);
      await tester.unmountApp();
    });
  });
}
