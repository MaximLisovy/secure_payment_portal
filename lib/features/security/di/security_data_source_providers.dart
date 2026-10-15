import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/data/datasources/security_platform_data_source.dart';

/// How long the simulated security scan takes, so the UI has a scan to show.
const Duration fakeSecurityScanLatency = Duration(milliseconds: 1500);

// Wiring only; not part of the feature's public barrel, except the mode.

/// The channel-based source. Null until the native milestone wires it: with no
/// real source, the simulation is the only option.
final realSecurityPlatformDataSourceProvider =
    Provider<SecurityPlatformDataSource?>((ref) => null);

/// The scripted device. Typed as the fake on purpose: it is both the data source
/// and the [SecurityScenarioControl], so nothing needs a downcast to steer it.
/// Override this one, not the selection below, to script a device in a test.
final simulatedSecurityPlatformDataSourceProvider =
    Provider<FakeSecurityPlatformDataSource>((ref) {
      final fake = FakeSecurityPlatformDataSource(
        latency: fakeSecurityScanLatency,
      );
      ref.onDispose(fake.dispose);
      return fake;
    });

/// Real by default once a real source exists; a debug build may switch.
final securitySourceModeProvider =
    NotifierProvider<SourceModeNotifier, SourceMode>(
      () => SourceModeNotifier(
        isRealAvailable: (ref) =>
            ref.read(realSecurityPlatformDataSourceProvider) != null,
      ),
    );

/// The source the feature runs on right now. Override this in tests to replace
/// the selection altogether.
final securityPlatformDataSourceProvider = Provider<SecurityPlatformDataSource>(
  (ref) {
    final real = ref.watch(realSecurityPlatformDataSourceProvider);
    if (real != null &&
        ref.watch(securitySourceModeProvider) == SourceMode.real) {
      return real;
    }
    return ref.watch(simulatedSecurityPlatformDataSourceProvider);
  },
);
