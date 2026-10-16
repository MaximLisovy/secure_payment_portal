import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/logging/logger_provider.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/features/security/data/datasources/channel_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';
// The public barrel, as another feature sees it.
import 'package:secure_payment_portal/features/security/security.dart';

import '../../../helpers/recording_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('by default the interfaces sit on the channel-based source', () {
    final container = ProviderContainer.test();

    expect(container.read(securitySourceModeProvider), SourceMode.real);
    expect(
      container.read(securityPlatformDataSourceProvider),
      isA<ChannelSecurityPlatformDataSource>(),
    );
    expect(container.read(securityScenarioControlProvider), isNull);
  });

  test('the simulation has a scan delay, so the UI has a scan to show', () {
    final container = ProviderContainer.test();
    container
        .read(securitySourceModeProvider.notifier)
        .select(SourceMode.simulated);

    expect(
      container.read(securityPlatformDataSourceProvider),
      isA<FakeSecurityPlatformDataSource>().having(
        (fake) => fake.latency,
        'latency',
        fakeSecurityScanLatency,
      ),
    );
  });

  test('the channels are plain providers, so a test can replace them', () {
    const methods = MethodChannel('test/security');
    const events = EventChannel('test/security/events');
    final container = ProviderContainer.test(
      overrides: [
        securityMethodChannelProvider.overrideWithValue(methods),
        securityRecordingEventChannelProvider.overrideWithValue(events),
      ],
    );

    expect(container.read(securityMethodChannelProvider), same(methods));
    expect(container.read(securityRecordingEventChannelProvider), same(events));
  });

  test('the channel source and the repositories use the app logger', () async {
    final logger = RecordingLogger();
    const methods = MethodChannel('test/security/logging');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (_) async {
          throw PlatformException(code: 'BROKEN', message: 'card 4111');
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methods, null),
    );
    final container = ProviderContainer.test(
      overrides: [
        loggerProvider.overrideWithValue(logger),
        securityMethodChannelProvider.overrideWithValue(methods),
      ],
    );

    final result = await container
        .read(secureWindowControllerProvider)
        .enable();

    expect(result.isSuccess, isFalse);
    expect(logger.warnings.single.message, contains('BROKEN'));
    expect(logger.entries.single.everything, isNot(contains('4111')));
  });

  test(
    'both interfaces are backed by the same overridden data source',
    () async {
      final fake = FakeSecurityPlatformDataSource()
        ..setRoot(DetectionWire.detected, signals: [RootReasonCodes.suBinary]);
      final container = ProviderContainer.test(
        overrides: [
          realSecurityPlatformDataSourceProvider.overrideWithValue(fake),
        ],
      );

      final status = await container
          .read(securityStatusRepositoryProvider)
          .getStatus();
      await container.read(secureWindowControllerProvider).enable();

      expect(status.valueOrNull?.root, isA<RootDetected>());
      expect(fake.secureWindowCount, 1);
    },
  );

  test('exposes the default policy, which can be overridden', () {
    final strict = ProviderContainer.test(
      overrides: [
        securityPolicyProvider.overrideWithValue(
          const SecurityPolicy(blockOnWeakRootSignals: true),
        ),
      ],
    );
    final defaults = ProviderContainer.test();

    expect(
      defaults.read(securityPolicyProvider).blockOnWeakRootSignals,
      isFalse,
    );
    expect(defaults.read(securityPolicyProvider).blockOnUnknownRoot, isTrue);
    expect(strict.read(securityPolicyProvider).blockOnWeakRootSignals, isTrue);
  });

  group('the source mode', () {
    // The channel-based source is wired by default; take it away to see the
    // simulation alone.
    ProviderContainer containerWithoutReal() => ProviderContainer.test(
      overrides: [
        realSecurityPlatformDataSourceProvider.overrideWithValue(null),
      ],
    );

    ProviderContainer containerWithReal(FakeSecurityPlatformDataSource real) =>
        ProviderContainer.test(
          overrides: [
            realSecurityPlatformDataSourceProvider.overrideWithValue(real),
          ],
        );

    test(
      'is simulated while no real source is wired, with controls to steer it',
      () {
        final container = containerWithoutReal();

        expect(
          container.read(securitySourceModeProvider),
          SourceMode.simulated,
        );
        final control = container.read(securityScenarioControlProvider);
        expect(control, isNotNull);
        expect(
          control,
          same(container.read(securityPlatformDataSourceProvider)),
          reason: 'the controls steer the very source the feature runs on',
        );
      },
    );

    test(
      'is real once a real source is wired, and then offers no controls',
      () {
        final real = FakeSecurityPlatformDataSource();
        final container = containerWithReal(real);

        expect(container.read(securitySourceModeProvider), SourceMode.real);
        expect(container.read(securityPlatformDataSourceProvider), same(real));
        expect(container.read(securityScenarioControlProvider), isNull);
      },
    );

    test(
      'switching to the simulation swaps the source and brings the controls',
      () {
        final real = FakeSecurityPlatformDataSource();
        final container = containerWithReal(real);

        container
            .read(securitySourceModeProvider.notifier)
            .select(SourceMode.simulated);

        expect(
          container.read(securityPlatformDataSourceProvider),
          isNot(same(real)),
        );
        expect(container.read(securityScenarioControlProvider), isNotNull);

        container
            .read(securitySourceModeProvider.notifier)
            .select(SourceMode.real);
        expect(container.read(securityPlatformDataSourceProvider), same(real));
        expect(container.read(securityScenarioControlProvider), isNull);
      },
    );

    test(
      'the simulation keeps its scenario across a switch there and back',
      () {
        final container = containerWithReal(FakeSecurityPlatformDataSource());
        final mode = container.read(securitySourceModeProvider.notifier)
          ..select(SourceMode.simulated);
        container
            .read(securityScenarioControlProvider)!
            .setDeviceScenario(DeviceScenario.rooted);

        mode
          ..select(SourceMode.real)
          ..select(SourceMode.simulated);

        expect(
          container.read(securityScenarioControlProvider)!.deviceScenario,
          DeviceScenario.rooted,
        );
      },
    );
  });

  // The simulation replaces readings, never the window: FLAG_SECURE is the real
  // one's in every mode.
  group('the secure window', () {
    late FakeSecurityPlatformDataSource real;
    late FakeSecurityPlatformDataSource simulated;
    late ProviderContainer container;

    setUp(() {
      real = FakeSecurityPlatformDataSource();
      simulated = FakeSecurityPlatformDataSource(scriptedWindow: true);
      container = ProviderContainer.test(
        overrides: [
          realSecurityPlatformDataSourceProvider.overrideWithValue(real),
          simulatedSecurityPlatformDataSourceProvider.overrideWithValue(
            simulated,
          ),
        ],
      );
    });

    void switchTo(SourceMode mode) =>
        container.read(securitySourceModeProvider.notifier).select(mode);

    test('goes to the real source while security is real', () async {
      await container.read(secureWindowControllerProvider).enable();

      expect(real.secureWindowCount, 1);
      expect(simulated.secureWindowCount, 0);
    });

    test('still goes to the real source once security is simulated', () async {
      switchTo(SourceMode.simulated);

      await container.read(secureWindowControllerProvider).enable();

      expect(real.secureWindowCount, 1, reason: 'the window is the real one');
      expect(simulated.secureWindowCount, 0);
    });

    test(
      'is the same controller before and after a switch, so nothing moves',
      () {
        final before = container.read(secureWindowControllerProvider);

        switchTo(SourceMode.simulated);
        switchTo(SourceMode.real);

        expect(container.read(secureWindowControllerProvider), same(before));
      },
    );

    test(
      'stays protected through a switch to the simulation and back',
      () async {
        final window = container.read(secureWindowProvider.notifier);
        await window.acquire();
        expect(real.secureWindowCount, 1);

        switchTo(SourceMode.simulated);
        await window.retry();
        expect(real.secureWindowCount, 1);

        switchTo(SourceMode.real);
        await window.retry();
        expect(
          real.secureWindowCount,
          1,
          reason: 'never stacked, never dropped',
        );

        await window.release();
        expect(real.secureWindowCount, 0);
      },
    );

    test(
      'is reported by the simulation as a script, not by the real window',
      () async {
        switchTo(SourceMode.simulated);
        final repository = container.read(securityStatusRepositoryProvider);
        await container.read(secureWindowControllerProvider).enable();

        expect(
          (await repository.getStatus()).valueOrNull?.windowProtection,
          WindowProtection.active,
        );

        container
            .read(securityScenarioControlProvider)!
            .setScreenProtectionAvailable(available: false);

        expect(
          (await repository.getStatus()).valueOrNull?.windowProtection,
          WindowProtection.inactive,
        );
        expect(real.secureWindowCount, 1, reason: 'only the reading changed');
      },
    );

    test(
      'is not simulated by the default simulation, which only scripts readings',
      () async {
        final container = ProviderContainer.test();
        container
            .read(securitySourceModeProvider.notifier)
            .select(SourceMode.simulated);

        final fake = container.read(
          simulatedSecurityPlatformDataSourceProvider,
        );

        expect(fake.scriptedWindow, isTrue);
        expect(
          (await fake.getSecurityStatus()).windowProtection,
          WindowProtectionWire.active,
          reason: 'a clean simulated device is payable without any window call',
        );
      },
    );

    test(
      'falls back to the selected source where no real one is wired',
      () async {
        final bare = ProviderContainer.test(
          overrides: [
            realSecurityPlatformDataSourceProvider.overrideWithValue(null),
            simulatedSecurityPlatformDataSourceProvider.overrideWithValue(
              FakeSecurityPlatformDataSource(),
            ),
          ],
        );

        expect(
          bare.read(secureWindowPlatformDataSourceProvider),
          same(bare.read(securityPlatformDataSourceProvider)),
        );
      },
    );
  });
}
