import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/app.dart';
import 'package:secure_payment_portal/app/di/root_overrides.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_config.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/di/payment_data_source_providers.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';
import 'package:secure_payment_portal/features/security/domain/security_decision.dart';
import 'package:secure_payment_portal/features/security/domain/security_scenario_control.dart';

typedef _Env = ({
  FakeSecurityPlatformDataSource simulatedDevice,
  FakeSecurityPlatformDataSource? realDevice,
  FakePaymentRemoteDataSource remote,
});

/// The whole app on fakes that the test holds. With [withRealSources] the
/// "real" slots are filled by other fakes, standing in for the native sources.
Future<_Env> _pumpApp(
  WidgetTester tester, {
  bool withRealSources = false,
}) async {
  tester.view
    ..physicalSize = const Size(800, 1800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final env = (
    simulatedDevice: FakeSecurityPlatformDataSource(),
    realDevice: withRealSources ? FakeSecurityPlatformDataSource() : null,
    remote: FakePaymentRemoteDataSource(),
  );
  final payments = FakePaymentPlatformDataSource(
    config: const FakePaymentConfig(stepDelay: Duration(milliseconds: 100)),
  );
  final realDevice = env.realDevice;
  await tester.pumpWidget(
    ProviderScope(
      retry: disableProviderRetry,
      overrides: [
        ...rootOverrides(initialBrand: retailBrand),
        simulatedSecurityPlatformDataSourceProvider.overrideWithValue(
          env.simulatedDevice,
        ),
        simulatedPaymentPlatformDataSourceProvider.overrideWithValue(payments),
        fakePaymentRemoteDataSourceProvider.overrideWithValue(env.remote),
        if (realDevice != null) ...[
          realSecurityPlatformDataSourceProvider.overrideWithValue(realDevice),
          realPaymentPlatformDataSourceProvider.overrideWithValue(
            FakePaymentPlatformDataSource(),
          ),
        ],
      ],
      child: const App(),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  return env;
}

Future<void> _openPanel(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.tune));
  await tester.pumpAndSettle();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

Finder _text(String message) => find.text(message);

void main() {
  testWidgets('the panel opens from the app bar', (tester) async {
    await _pumpApp(tester);

    await _openPanel(tester);

    expect(find.text(AppStrings.demoScenarios), findsOneWidget);
  });

  testWidgets('a rooted device blocks payment on the screen', (tester) async {
    await _pumpApp(tester);
    expect(_text(AppStrings.securityVerified), findsOneWidget);
    await _openPanel(tester);

    await tester.tap(find.text(AppStrings.demoDeviceRooted));
    await _settle(tester);

    expect(
      _text(AppStrings.message(SecurityBlockReason.rootDetected.messageKey)),
      findsOneWidget,
    );
    expect(_text(AppStrings.securityVerified), findsNothing);
  });

  testWidgets(
    'a recording blocks payment live, and stops blocking when it ends',
    (tester) async {
      await _pumpApp(tester);
      await _openPanel(tester);
      final recording = find.widgetWithText(
        SwitchListTile,
        AppStrings.demoRecording,
      );

      await tester.tap(recording);
      await _settle(tester);
      expect(
        _text(
          AppStrings.message(SecurityBlockReason.screenRecording.messageKey),
        ),
        findsOneWidget,
      );

      await tester.tap(recording);
      await _settle(tester);
      expect(_text(AppStrings.securityVerified), findsOneWidget);
    },
  );

  testWidgets(
    'a bill backend that goes offline shows the error, and recovers',
    (tester) async {
      await _pumpApp(tester);
      await _openPanel(tester);
      final backend = find.widgetWithText(
        SwitchListTile,
        AppStrings.demoBackendOnline,
      );

      await tester.tap(backend);
      await _settle(tester);
      expect(
        _text(AppStrings.message(const NetworkFailure().messageKey)),
        findsOneWidget,
      );

      await tester.tap(backend);
      await _settle(tester);
      expect(_text(AppStrings.securityVerified), findsOneWidget);
    },
  );

  group('starting on real sources', () {
    testWidgets(
      'there is no SIMULATED badge, and the real device is protected',
      (tester) async {
        final env = await _pumpApp(tester, withRealSources: true);

        expect(_text(AppStrings.simulatedBadge), findsNothing);
        expect(_text(AppStrings.securityVerified), findsOneWidget);
        expect(env.realDevice!.secureWindowCount, 1);
        expect(env.simulatedDevice.secureWindowCount, 0);
      },
    );

    testWidgets('switching the device to Simulated restarts on the simulation', (
      tester,
    ) async {
      final env = await _pumpApp(tester, withRealSources: true);
      env.simulatedDevice.setDeviceScenario(DeviceScenario.rooted);
      await _openPanel(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<SourceMode>).first,
          matching: find.text(AppStrings.demoSourceSimulated),
        ),
      );
      await _settle(tester);

      expect(_text(AppStrings.simulatedBadge), findsOneWidget);
      expect(
        _text(AppStrings.message(SecurityBlockReason.rootDetected.messageKey)),
        findsOneWidget,
      );
      // The protection followed the switch: nothing is left on the real device.
      expect(env.realDevice!.secureWindowCount, 0);
      expect(env.simulatedDevice.secureWindowCount, 1);
    });
  });
}
