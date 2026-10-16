import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';
import 'package:secure_payment_portal/features/security/security.dart';

import '../helpers/gated_secure_window_controller.dart';

({ProviderContainer container, SecureWindowNotifier notifier}) _setup(
  FakeSecurityPlatformDataSource fake,
) {
  final container = ProviderContainer.test(
    overrides: [realSecurityPlatformDataSourceProvider.overrideWithValue(fake)],
  );
  return (
    container: container,
    notifier: container.read(secureWindowProvider.notifier),
  );
}

void main() {
  group('SecureWindowNotifier', () {
    test('replacement after a failed enable is still reconciled', () async {
      final fake = FakeSecurityPlatformDataSource()
        ..setScreenProtectionAvailable(available: false);
      final (:container, :notifier) = _setup(fake);
      await notifier.acquire();
      fake.setScreenProtectionAvailable(available: true);
      final releasing = notifier.release();
      final acquiring = notifier.acquire();
      await Future.wait([releasing, acquiring]);
      expect(fake.secureWindowCount, 1);
      expect(
        container.read(secureWindowProvider),
        const SecureWindowProtected(),
      );
      await notifier.release();
    });

    test(
      'an acquire during disable waits and protects the new holder',
      () async {
        final disabling = Completer<Result<void>>();
        final gate = GatedSecureWindowController(disableAnswer: disabling);
        final container = ProviderContainer.test(
          overrides: [secureWindowControllerProvider.overrideWithValue(gate)],
        );
        final notifier = container.read(secureWindowProvider.notifier);
        gate.answer.complete(Success.unit);
        await notifier.acquire();

        final releasing = notifier.release();
        final acquiring = notifier.acquire();
        expect(gate.enables, 1);
        disabling.complete(Success.unit);
        await Future.wait([releasing, acquiring]);

        expect(gate.enables, 2);
        expect(gate.disables, 1);
        expect(
          container.read(secureWindowProvider),
          const SecureWindowProtected(),
        );
        await notifier.release();
        expect(gate.disables, 2);
      },
    );

    test(
      'a failed disable does not stack another claim on reacquire',
      () async {
        final fake = FakeSecurityPlatformDataSource();
        final (:container, :notifier) = _setup(fake);
        await notifier.acquire();
        fake.failWith(const NetworkException());
        await notifier.release();
        fake.failWith(null);

        await notifier.acquire();
        expect(fake.secureWindowCount, 1);
        expect(
          container.read(secureWindowProvider),
          const SecureWindowProtected(),
        );
        await notifier.release();
        expect(fake.secureWindowCount, 0);
      },
    );
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
        ..setScreenProtectionAvailable(available: false);
      final (:container, :notifier) = _setup(fake);

      await notifier.acquire();

      expect(
        container.read(secureWindowProvider),
        const SecureWindowFailed(
          PlatformFailure(ChannelErrorCodes.unavailable),
        ),
      );
      expect(fake.secureWindowCount, 0);

      fake.setScreenProtectionAvailable(available: true);
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

  // A screen asks for protection from `initState`; the platform answers later.
  group('while the platform has not answered', () {
    ({
      ProviderContainer container,
      SecureWindowNotifier notifier,
      GatedSecureWindowController gate,
    })
    setUpGate() {
      final gate = GatedSecureWindowController();
      final container = ProviderContainer.test(
        overrides: [secureWindowControllerProvider.overrideWithValue(gate)],
      );
      return (
        container: container,
        notifier: container.read(secureWindowProvider.notifier),
        gate: gate,
      );
    }

    test(
      'the request is sent at once, the state says pending, not failed',
      () async {
        final (:container, :notifier, :gate) = setUpGate();

        unawaited(notifier.acquire());

        expect(gate.enables, 1, reason: 'sent before anything else can run');
        await pumpEventQueue();
        expect(
          container.read(secureWindowProvider),
          const SecureWindowPending(),
        );
      },
    );

    test('settled() waits for the answer, then completes', () async {
      final (:container, :notifier, :gate) = setUpGate();
      unawaited(notifier.acquire());
      var settled = false;
      unawaited(notifier.settled().then((_) => settled = true));
      await pumpEventQueue();
      expect(settled, isFalse);

      gate.answer.complete(Success.unit);
      await pumpEventQueue();

      expect(settled, isTrue);
      expect(
        container.read(secureWindowProvider),
        const SecureWindowProtected(),
      );
    });

    test(
      'a failure also settles it, as a failed state and not as a throw',
      () async {
        final (:container, :notifier, :gate) = setUpGate();
        unawaited(notifier.acquire());
        var settled = false;
        unawaited(notifier.settled().then((_) => settled = true));

        gate.answer.complete(
          const Err(PlatformFailure(ChannelErrorCodes.unavailable)),
        );
        await pumpEventQueue();

        expect(settled, isTrue);
        expect(container.read(secureWindowProvider), isA<SecureWindowFailed>());
      },
    );

    test('settled() completes at once when nothing was asked', () async {
      final (:container, :notifier, :gate) = setUpGate();

      await notifier.settled();

      expect(container.read(secureWindowProvider), const SecureWindowIdle());
      expect(gate.enables, 0);
    });

    test('a second screen does not send a second request', () async {
      final (:container, :notifier, :gate) = setUpGate();

      unawaited(notifier.acquire());
      unawaited(notifier.acquire());
      gate.answer.complete(Success.unit);
      await pumpEventQueue();

      expect(gate.enables, 1);
    });

    test('retry shares an enable that is still pending', () async {
      final (:container, :notifier, :gate) = setUpGate();
      final acquiring = notifier.acquire();
      final retrying = notifier.retry();
      expect(gate.enables, 1);

      gate.answer.complete(Success.unit);
      await Future.wait([acquiring, retrying]);
      await notifier.release();

      expect(gate.disables, 1);
      expect(container.read(secureWindowProvider), const SecureWindowIdle());
    });

    test('a new holder arriving during enable reuses its claim', () async {
      final (:container, :notifier, :gate) = setUpGate();
      final first = notifier.acquire();
      await notifier.release();
      final second = notifier.acquire();
      gate.answer.complete(Success.unit);
      await Future.wait([first, second]);

      expect(gate.enables, 1);
      expect(gate.disables, 0);
      expect(
        container.read(secureWindowProvider),
        const SecureWindowProtected(),
      );
      await notifier.release();
      expect(gate.disables, 1);
    });

    test('leaving before the answer unprotects as soon as it comes', () async {
      final (:container, :notifier, :gate) = setUpGate();
      unawaited(notifier.acquire());
      await notifier.release();
      expect(gate.disables, 0, reason: 'nothing is enabled yet');

      gate.answer.complete(Success.unit);
      await pumpEventQueue();

      expect(gate.disables, 1);
      expect(container.read(secureWindowProvider), const SecureWindowIdle());
    });
  });
}
