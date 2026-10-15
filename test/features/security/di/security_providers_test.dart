import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';
// The public barrel, as another feature sees it.
import 'package:secure_payment_portal/features/security/security.dart';

void main() {
  test(
    'by default the interfaces sit on one fake data source with a scan delay',
    () {
      final container = ProviderContainer.test();

      final dataSource = container.read(securityPlatformDataSourceProvider);

      expect(
        dataSource,
        isA<FakeSecurityPlatformDataSource>().having(
          (fake) => fake.latency,
          'latency',
          fakeSecurityScanLatency,
        ),
      );
    },
  );

  test(
    'both interfaces are backed by the same overridden data source',
    () async {
      final fake = FakeSecurityPlatformDataSource()
        ..setRoot(DetectionWire.detected, signals: [RootReasonCodes.suBinary]);
      final container = ProviderContainer.test(
        overrides: [securityPlatformDataSourceProvider.overrideWithValue(fake)],
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
    ProviderContainer containerWithReal(FakeSecurityPlatformDataSource real) =>
        ProviderContainer.test(
          overrides: [
            realSecurityPlatformDataSourceProvider.overrideWithValue(real),
          ],
        );

    test(
      'is simulated while no real source is wired, with controls to steer it',
      () {
        final container = ProviderContainer.test();

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
}
