import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/data/datasources/security_platform_data_source.dart';

/// How long the fake security scan takes, so the UI has a scan to show.
const Duration fakeSecurityScanLatency = Duration(milliseconds: 1500);

/// Wiring only; not part of the feature's public barrel. Override this in
/// tests, or swap the body for the channel-based source when it exists.
final securityPlatformDataSourceProvider = Provider<SecurityPlatformDataSource>(
  (ref) {
    final fake = FakeSecurityPlatformDataSource(
      latency: fakeSecurityScanLatency,
    );
    ref.onDispose(fake.dispose);
    return fake;
  },
);
