import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/features/security/data/datasources/security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/data/mappers/security_status_mapper.dart';

/// What every [SecurityPlatformDataSource] must do, whatever is behind it.
/// Run against the fake now; in the native milestone the same suite runs
/// against the channel-based source (with a mocked binary messenger), which is
/// what makes the swap safe.
void securityPlatformDataSourceContract(
  String name,
  SecurityPlatformDataSource Function() create,
) {
  group('SecurityPlatformDataSource contract: $name', () {
    test('getSecurityStatus returns a status the mapper accepts', () async {
      final dto = await create().getSecurityStatus();

      expect(() => SecurityStatusMapper.toEntity(dto), returnsNormally);
    });

    test('replays the current recording state to the first listener', () async {
      final source = create();
      final status = await source.getSecurityStatus();

      final first = await source.watchScreenRecording().first;

      expect(first.screenRecording, status.screenRecording);
    });

    test(
      'replays the current recording state to every later listener',
      () async {
        final source = create();

        final a = await source.watchScreenRecording().first;
        final b = await source.watchScreenRecording().first;

        expect(b, a);
      },
    );

    test(
      'secure window calls can be balanced, and an extra disable is ignored',
      () async {
        final source = create();

        await source.enableSecureWindow();
        await source.enableSecureWindow();
        await source.disableSecureWindow();
        await source.disableSecureWindow();
        await source.disableSecureWindow();
      },
    );
  });
}
