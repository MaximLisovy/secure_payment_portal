import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/features/security/data/datasources/channel_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/data/datasources/security_platform_data_source.dart';

/// How long the simulated security scan takes, so the UI has a scan to show.
const Duration fakeSecurityScanLatency = Duration(milliseconds: 1500);

// Wiring only; not part of the feature's public barrel, except the mode.

/// The channels to the Kotlin `SecurityPlugin`. Plain providers, so a test can
/// replace them.
final securityMethodChannelProvider = Provider<MethodChannel>(
  (ref) => const MethodChannel(SecurityChannel.methods),
);

final securityRecordingEventChannelProvider = Provider<EventChannel>(
  (ref) => const EventChannel(SecurityChannel.recordingEvents),
);

/// The channel-based source: the real device. It is the default. Where there is
/// no native side (iOS, desktop, plain `flutter test`) every call fails as
/// unsupported, so the device reads as unverifiable and payment is refused, as the
/// README says; a debug build can switch to the simulation. Nullable so a test
/// can override it with null and get the simulation back as the only option.
final realSecurityPlatformDataSourceProvider =
    Provider<SecurityPlatformDataSource?>((ref) {
      final source = ChannelSecurityPlatformDataSource(
        methods: ref.watch(securityMethodChannelProvider),
        recordingEvents: ref.watch(securityRecordingEventChannelProvider),
      );
      ref.onDispose(source.dispose);
      return source;
    });

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
