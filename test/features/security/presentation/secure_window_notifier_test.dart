import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';
import 'package:secure_payment_portal/features/security/security.dart';

({ProviderContainer container, SecureWindowNotifier notifier}) _setup(
  FakeSecurityPlatformDataSource fake,
) {
  final container = ProviderContainer.test(
    overrides: [securityPlatformDataSourceProvider.overrideWithValue(fake)],
  );
  return (
    container: container,
    notifier: container.read(secureWindowProvider.notifier),
  );
}

void main() {
  group('SecureWindowNotifier', () {
    test('starts idle and protects on the first acquire', () async {
      final fake = FakeSecurityPlatformDataSource();
      final (:container, :notifier) = _setup(fake);
      expect(container.read(secureWindowProvider), const SecureWindowIdle());

      await notifier.acquire();

      expect(
        container.read(secureWindowProvider),
        const SecureWindowProtected(),
      );
      expect(fake.secureWindowCount, 1);
    });

    test(
      'asks the platform only for the first acquire and the last release',
      () async {
        final fake = FakeSecurityPlatformDataSource();
        final (:container, :notifier) = _setup(fake);

        await notifier.acquire();
        await notifier.acquire();
        expect(
          fake.secureWindowCount,
          1,
          reason: 'a second screen must not stack',
        );

        await notifier.release();
        expect(fake.secureWindowCount, 1, reason: 'one screen still needs it');
        expect(
          container.read(secureWindowProvider),
          const SecureWindowProtected(),
        );

        await notifier.release();
        expect(fake.secureWindowCount, 0);
        expect(container.read(secureWindowProvider), const SecureWindowIdle());
      },
    );

    test('ignores a release that has nothing to balance', () async {
      final fake = FakeSecurityPlatformDataSource();
      final (:container, :notifier) = _setup(fake);

      await notifier.release();
      await notifier.acquire();
      await notifier.release();
      await notifier.release();

      expect(fake.secureWindowCount, 0);
      expect(container.read(secureWindowProvider), const SecureWindowIdle());
    });

    test('reports a failure to protect, and can try again', () async {
      final fake = FakeSecurityPlatformDataSource()
        ..setWindowProtectionWorks(works: false);
      final (:container, :notifier) = _setup(fake);

      await notifier.acquire();

      expect(
        container.read(secureWindowProvider),
        const SecureWindowFailed(
          PlatformFailure(ChannelErrorCodes.unavailable),
        ),
      );
      expect(fake.secureWindowCount, 0);

      fake.setWindowProtectionWorks(works: true);
      await notifier.retry();

      expect(
        container.read(secureWindowProvider),
        const SecureWindowProtected(),
      );
      expect(fake.secureWindowCount, 1);

      await notifier.release();
      expect(fake.secureWindowCount, 0);
    });

    test(
      'a retry does nothing without a screen that needs protection',
      () async {
        final fake = FakeSecurityPlatformDataSource();
        final (:container, :notifier) = _setup(fake);

        await notifier.retry();

        expect(fake.secureWindowCount, 0);
        expect(container.read(secureWindowProvider), const SecureWindowIdle());
      },
    );

    test('a retry does not enable twice when already protected', () async {
      final fake = FakeSecurityPlatformDataSource();
      final (:container, :notifier) = _setup(fake);
      await notifier.acquire();

      await notifier.retry();

      expect(fake.secureWindowCount, 1);
    });

    test(
      'a screen that leaves before the platform answers leaves nothing enabled',
      () async {
        final fake = FakeSecurityPlatformDataSource();
        final (:container, :notifier) = _setup(fake);

        final acquiring = notifier.acquire();
        final releasing = notifier.release();
        await Future.wait([acquiring, releasing]);

        expect(fake.secureWindowCount, 0);
        expect(container.read(secureWindowProvider), const SecureWindowIdle());
      },
    );

    test(
      'a failed release leaves the window protected, the safe side',
      () async {
        final fake = FakeSecurityPlatformDataSource();
        final (:container, :notifier) = _setup(fake);
        await notifier.acquire();

        fake.failWith(const NetworkException());
        await notifier.release();

        expect(fake.secureWindowCount, 1);
      },
    );
  });

  // A debug build can switch the security source under a visible screen.
  group('when the source is switched', () {
    ({
      ProviderContainer container,
      FakeSecurityPlatformDataSource real,
      FakeSecurityPlatformDataSource simulated,
    })
    setUpSources() {
      final real = FakeSecurityPlatformDataSource();
      final simulated = FakeSecurityPlatformDataSource();
      final container = ProviderContainer.test(
        overrides: [
          realSecurityPlatformDataSourceProvider.overrideWithValue(real),
          simulatedSecurityPlatformDataSourceProvider.overrideWithValue(
            simulated,
          ),
        ],
      );
      return (container: container, real: real, simulated: simulated);
    }

    test(
      'retry moves protection to the new source while a screen needs it',
      () async {
        final (:container, :real, :simulated) = setUpSources();
        final notifier = container.read(secureWindowProvider.notifier);
        await notifier.acquire();
        expect(real.secureWindowCount, 1);

        container
            .read(securitySourceModeProvider.notifier)
            .select(SourceMode.simulated);
        await notifier.retry();

        expect(real.secureWindowCount, 0);
        expect(simulated.secureWindowCount, 1);
        expect(
          container.read(secureWindowProvider),
          const SecureWindowProtected(),
        );

        await notifier.release();
        expect(simulated.secureWindowCount, 0);
      },
    );

    test(
      'releasing after a switch unprotects the source that was protected',
      () async {
        final (:container, :real, :simulated) = setUpSources();
        final notifier = container.read(secureWindowProvider.notifier);
        await notifier.acquire();

        container
            .read(securitySourceModeProvider.notifier)
            .select(SourceMode.simulated);
        await notifier.release();

        expect(real.secureWindowCount, 0, reason: 'it must not stay protected');
        expect(simulated.secureWindowCount, 0);
      },
    );

    test(
      'nothing is protected on the new source when no screen needs it',
      () async {
        final (:container, :real, :simulated) = setUpSources();
        final notifier = container.read(secureWindowProvider.notifier);
        await notifier.acquire();
        await notifier.release();

        container
            .read(securitySourceModeProvider.notifier)
            .select(SourceMode.simulated);
        await notifier.retry();

        expect(real.secureWindowCount, 0);
        expect(simulated.secureWindowCount, 0);
        expect(container.read(secureWindowProvider), const SecureWindowIdle());
      },
    );

    test(
      'a new source that cannot protect shows as failed, until it can',
      () async {
        final (:container, :real, :simulated) = setUpSources();
        simulated.setWindowProtectionWorks(works: false);
        final notifier = container.read(secureWindowProvider.notifier);
        await notifier.acquire();

        container
            .read(securitySourceModeProvider.notifier)
            .select(SourceMode.simulated);
        await notifier.retry();
        expect(container.read(secureWindowProvider), isA<SecureWindowFailed>());

        simulated.setWindowProtectionWorks(works: true);
        await notifier.retry();

        expect(simulated.secureWindowCount, 1);
        expect(
          container.read(secureWindowProvider),
          const SecureWindowProtected(),
        );
      },
    );
  });
}
