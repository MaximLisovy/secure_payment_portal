import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/debug/demo_scenarios_panel.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/di/payment_data_source_providers.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';
import 'package:secure_payment_portal/features/security/security.dart';

import '../../helpers/pump_app.dart';

typedef _Sources = ({
  FakeSecurityPlatformDataSource security,
  FakePaymentPlatformDataSource payments,
  FakePaymentRemoteDataSource remote,
});

/// Pumps only the panel. The simulated sources are the ones the test holds, so
/// it can look at what the panel did to them.
Future<_Sources> _pumpPanel(
  WidgetTester tester, {
  bool withRealSources = false,
  FakeSecurityPlatformDataSource? realDevice,
  List<Override> extra = const [],
}) async {
  // The panel is taller than the default test screen; a sheet scrolls, but the
  // tests should not have to.
  tester.view
    ..physicalSize = const Size(800, 1800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sources = (
    security: FakeSecurityPlatformDataSource(),
    payments: FakePaymentPlatformDataSource(),
    remote: FakePaymentRemoteDataSource(),
  );
  await tester.pumpApp(
    const Scaffold(body: DemoScenariosPanel()),
    brand: retailBrand,
    overrides: [
      simulatedSecurityPlatformDataSourceProvider.overrideWithValue(
        sources.security,
      ),
      simulatedPaymentPlatformDataSourceProvider.overrideWithValue(
        sources.payments,
      ),
      fakePaymentRemoteDataSourceProvider.overrideWithValue(sources.remote),
      // Real is the default once wired, so "no real source" is said out loud.
      realSecurityPlatformDataSourceProvider.overrideWithValue(
        withRealSources
            ? (realDevice ?? FakeSecurityPlatformDataSource())
            : null,
      ),
      if (withRealSources)
        realPaymentPlatformDataSourceProvider.overrideWithValue(
          FakePaymentPlatformDataSource(),
        ),
      ...extra,
    ],
  );
  return sources;
}

Finder _modePicker(int index) =>
    find.byType(SegmentedButton<SourceMode>).at(index);

SegmentedButton<SourceMode> _picker(WidgetTester tester, int index) =>
    tester.widget(_modePicker(index));

void main() {
  group('with no real source wired', () {
    testWidgets('both sources are simulated and Real cannot be picked', (
      tester,
    ) async {
      await _pumpPanel(tester);

      for (final index in [0, 1]) {
        final picker = _picker(tester, index);
        expect(picker.selected, {SourceMode.simulated});
        final real = picker.segments.firstWhere(
          (segment) => segment.value == SourceMode.real,
        );
        expect(real.enabled, isFalse);
      }
    });

    testWidgets('a device scenario steers the simulated device', (
      tester,
    ) async {
      final sources = await _pumpPanel(tester);

      await tester.tap(find.text(AppStrings.demoDeviceRooted));
      await tester.pump();

      expect(sources.security.deviceScenario, DeviceScenario.rooted);
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, AppStrings.demoDeviceRooted),
            )
            .selected,
        isTrue,
      );
    });

    testWidgets('the recording switch starts and stops a recording', (
      tester,
    ) async {
      final sources = await _pumpPanel(tester);
      final recording = find.widgetWithText(
        SwitchListTile,
        AppStrings.demoRecording,
      );

      await tester.tap(recording);
      await tester.pump();
      expect(sources.security.recordingActive, isTrue);

      await tester.tap(recording);
      await tester.pump();
      expect(sources.security.recordingActive, isFalse);
    });

    testWidgets('a payment outcome steers the simulated processing', (
      tester,
    ) async {
      final sources = await _pumpPanel(tester);

      await tester.tap(find.text(AppStrings.demoPaymentDeclined));
      await tester.pump();

      expect(sources.payments.scenario, PaymentScenario.declined);
    });

    testWidgets('the backend switch takes the bill backend offline', (
      tester,
    ) async {
      final sources = await _pumpPanel(tester);

      await tester.tap(
        find.widgetWithText(SwitchListTile, AppStrings.demoBackendOnline),
      );
      await tester.pump();

      expect(sources.remote.online, isFalse);
    });
  });

  group('while a payment is in progress', () {
    testWidgets('neither source can be switched, and it says why', (
      tester,
    ) async {
      await _pumpPanel(
        tester,
        withRealSources: true,
        extra: [paymentInProgressProvider.overrideWithValue(true)],
      );

      for (final index in [0, 1]) {
        expect(_picker(tester, index).onSelectionChanged, isNull);
        expect(_picker(tester, index).selected, {SourceMode.real});
      }
      expect(find.text(AppStrings.demoSourcesLocked), findsOneWidget);
    });

    testWidgets('a tap on the other mode changes nothing', (tester) async {
      await _pumpPanel(
        tester,
        withRealSources: true,
        extra: [paymentInProgressProvider.overrideWithValue(true)],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DemoScenariosPanel)),
      );

      await tester.tap(
        find.descendant(
          of: _modePicker(1),
          matching: find.text(AppStrings.demoSourceSimulated),
        ),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(container.read(paymentSourceModeProvider), SourceMode.real);
    });

    testWidgets('scenarios of a simulated source stay available', (
      tester,
    ) async {
      final sources = await _pumpPanel(
        tester,
        extra: [paymentInProgressProvider.overrideWithValue(true)],
      );

      await tester.tap(find.text(AppStrings.demoPaymentDeclined));
      await tester.pump();

      expect(sources.payments.scenario, PaymentScenario.declined);
    });
  });

  testWidgets('with no payment running the sources can be switched', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      withRealSources: true,
      extra: [paymentInProgressProvider.overrideWithValue(false)],
    );

    for (final index in [0, 1]) {
      expect(_picker(tester, index).onSelectionChanged, isNotNull);
    }
    expect(find.text(AppStrings.demoSourcesLocked), findsNothing);
  });

  group('the device reports', () {
    Finder title() => find.text(AppStrings.demoReportTitle);

    testWidgets(
      'are shown, read-only, while security runs on the real device',
      (tester) async {
        final device = FakeSecurityPlatformDataSource()
          ..setDeviceScenario(DeviceScenario.rooted);
        await _pumpPanel(tester, withRealSources: true, realDevice: device);
        await tester.pump();
        await tester.pump();

        expect(title(), findsOneWidget);
        expect(
          find.text('Detected: magiskArtifacts, suBinary'),
          findsOneWidget,
        );
        expect(find.text(AppStrings.demoReportNotDetected), findsOneWidget);
        expect(find.text(AppStrings.demoReportInactive), findsOneWidget);
        // Nothing to play on a real device.
        expect(find.text(AppStrings.demoDeviceRooted), findsNothing);
      },
    );

    testWidgets('say not detected for a clean device', (tester) async {
      await _pumpPanel(tester, withRealSources: true);
      await tester.pump();
      await tester.pump();

      // Root and screen recording.
      expect(find.text(AppStrings.demoReportNotDetected), findsNWidgets(2));
      expect(
        find.textContaining('${AppStrings.demoReportDetected}:'),
        findsNothing,
      );
    });

    testWidgets('can be read again', (tester) async {
      final device = FakeSecurityPlatformDataSource();
      await _pumpPanel(tester, withRealSources: true, realDevice: device);
      await tester.pump();
      await tester.pump();
      expect(find.text('Detected: suBinary, magiskArtifacts'), findsNothing);

      device.setDeviceScenario(DeviceScenario.rootedWeakOnly);
      await tester.tap(find.text(AppStrings.demoReportRefresh));
      await tester.pump();
      await tester.pump();

      expect(find.text('Detected: testKeys'), findsOneWidget);
    });

    testWidgets('follow a screen recording that starts', (tester) async {
      final device = FakeSecurityPlatformDataSource();
      await _pumpPanel(tester, withRealSources: true, realDevice: device);
      await tester.pump();
      await tester.pump();
      expect(find.text(AppStrings.demoReportDetected), findsNothing);

      device.setRecordingActive(active: true);
      await tester.pump();
      await tester.pump();

      expect(find.text(AppStrings.demoReportDetected), findsOneWidget);
    });

    testWidgets(
      'are not shown for the simulation, which has controls instead',
      (tester) async {
        await _pumpPanel(tester);
        await tester.pump();

        expect(title(), findsNothing);
        expect(find.text(AppStrings.demoDeviceRooted), findsOneWidget);
      },
    );

    testWidgets('appear when security is switched to the real device', (
      tester,
    ) async {
      await _pumpPanel(tester, withRealSources: true);
      await tester.tap(
        find.descendant(
          of: _modePicker(0),
          matching: find.text(AppStrings.demoSourceSimulated),
        ),
      );
      await tester.pump();
      expect(title(), findsNothing);

      await tester.tap(
        find.descendant(
          of: _modePicker(0),
          matching: find.text(AppStrings.demoSourceReal),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(title(), findsOneWidget);
    });
  });

  group('with real sources wired', () {
    testWidgets('they are the default and no scenario can be played on them', (
      tester,
    ) async {
      await _pumpPanel(tester, withRealSources: true);

      for (final index in [0, 1]) {
        expect(_picker(tester, index).selected, {SourceMode.real});
      }
      expect(find.text(AppStrings.demoDeviceRooted), findsNothing);
      expect(find.text(AppStrings.demoPaymentDeclined), findsNothing);
      expect(find.text(AppStrings.demoRecording), findsNothing);
      // The bill backend has no real counterpart and is always steerable.
      expect(find.text(AppStrings.demoBackendOnline), findsOneWidget);
    });

    testWidgets('switching a source to Simulated reveals its scenarios', (
      tester,
    ) async {
      final sources = await _pumpPanel(tester, withRealSources: true);

      await tester.tap(
        find.descendant(
          of: _modePicker(0),
          matching: find.text(AppStrings.demoSourceSimulated),
        ),
      );
      await tester.pump();

      expect(_picker(tester, 0).selected, {SourceMode.simulated});
      expect(_picker(tester, 1).selected, {SourceMode.real});
      expect(find.text(AppStrings.demoDeviceRooted), findsOneWidget);
      expect(find.text(AppStrings.demoPaymentDeclined), findsNothing);

      await tester.tap(find.text(AppStrings.demoDeviceRooted));
      await tester.pump();
      expect(sources.security.deviceScenario, DeviceScenario.rooted);
    });
  });
}
