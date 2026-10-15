import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
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
}
