import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/domain/security_scenario_control.dart';

import '../security_platform_data_source_contract.dart';

void main() {
  securityPlatformDataSourceContract(
    'FakeSecurityPlatformDataSource',
    FakeSecurityPlatformDataSource.new,
  );

  group('FakeSecurityPlatformDataSource', () {
    test('is a clean device by default', () async {
      final status = await FakeSecurityPlatformDataSource().getSecurityStatus();

      expect(status, FakeSecurityPlatformDataSource.cleanDevice);
    });

    test(
      'reports the window as protected only while an enable is unbalanced',
      () async {
        final source = FakeSecurityPlatformDataSource();
        Future<String> protection() async =>
            (await source.getSecurityStatus()).windowProtection;

        expect(await protection(), WindowProtectionWire.inactive);
        await source.enableSecureWindow();
        expect(await protection(), WindowProtectionWire.active);
        await source.enableSecureWindow();
        await source.disableSecureWindow();
        expect(await protection(), WindowProtectionWire.active);
        await source.disableSecureWindow();
        expect(await protection(), WindowProtectionWire.inactive);
      },
    );

    test('can play a device that cannot protect its window', () async {
      final source = FakeSecurityPlatformDataSource()
        ..setScreenProtectionAvailable(available: false);

      await expectLater(
        source.enableSecureWindow(),
        throwsA(
          isA<PlatformCallException>().having(
            (e) => e.code,
            'code',
            ChannelErrorCodes.unavailable,
          ),
        ),
      );

      expect(source.secureWindowCount, 0);
      expect(
        (await source.getSecurityStatus()).windowProtection,
        WindowProtectionWire.inactive,
      );

      source.setScreenProtectionAvailable(available: true);
      await source.enableSecureWindow();
      expect(source.screenProtectionAvailable, isTrue);
      expect(source.secureWindowCount, 1);
    });

    test('plays a rooted device scenario', () async {
      final source = FakeSecurityPlatformDataSource()
        ..setRoot(DetectionWire.detected, signals: [RootReasonCodes.testKeys]);

      final status = await source.getSecurityStatus();

      expect(status.root, DetectionWire.detected);
      expect(status.rootSignals, [RootReasonCodes.testKeys]);
    });

    test(
      'a recording change is visible to the query and to listeners',
      () async {
        final source = FakeSecurityPlatformDataSource();
        final events = <String>[];
        final subscription = source.watchScreenRecording().listen(
          (event) => events.add(event.screenRecording),
        );
        await pumpEventQueue();

        source.setScreenRecording(DetectionWire.detected);
        await pumpEventQueue();

        expect(events, [DetectionWire.notDetected, DetectionWire.detected]);
        expect(
          (await source.getSecurityStatus()).screenRecording,
          DetectionWire.detected,
        );
        await subscription.cancel();
      },
    );

    test(
      'a listener added after a change still sees the current state',
      () async {
        final source = FakeSecurityPlatformDataSource()
          ..setScreenRecording(DetectionWire.detected);

        final first = await source.watchScreenRecording().first;

        expect(first.screenRecording, DetectionWire.detected);
      },
    );

    test(
      'every call throws the configured failure, until it is cleared',
      () async {
        final source = FakeSecurityPlatformDataSource()
          ..failWith(const NetworkException());

        await expectLater(
          source.getSecurityStatus(),
          throwsA(isA<NetworkException>()),
        );
        await expectLater(
          source.enableSecureWindow(),
          throwsA(isA<NetworkException>()),
        );
        await expectLater(
          source.disableSecureWindow(),
          throwsA(isA<NetworkException>()),
        );

        source.failWith(null);
        expect(
          await source.getSecurityStatus(),
          FakeSecurityPlatformDataSource.cleanDevice,
        );
      },
    );

    test('counts unbalanced enables and never goes below zero', () async {
      final source = FakeSecurityPlatformDataSource();

      await source.enableSecureWindow();
      await source.enableSecureWindow();
      expect(source.secureWindowCount, 2);

      await source.disableSecureWindow();
      expect(source.secureWindowCount, 1);

      await source.disableSecureWindow();
      await source.disableSecureWindow();
      expect(source.secureWindowCount, 0);
    });

    test('getSecurityStatus takes exactly the configured latency', () {
      fakeAsync((async) {
        final source = FakeSecurityPlatformDataSource(
          latency: const Duration(seconds: 2),
        );
        var done = false;
        unawaited(source.getSecurityStatus().then((_) => done = true));

        async.elapse(const Duration(seconds: 1));
        expect(done, isFalse);

        async.elapse(const Duration(seconds: 1));
        expect(done, isTrue);
      });
    });

    test('dispose completes the recording stream', () async {
      final source = FakeSecurityPlatformDataSource();
      var done = false;
      final subscription = source.watchScreenRecording().listen(
        (_) {},
        onDone: () => done = true,
      );

      await source.dispose();
      await pumpEventQueue();

      expect(done, isTrue);
      await subscription.cancel();
    });
  });

  // The demo panel reaches the fake only through this interface.
  group('as a SecurityScenarioControl', () {
    SecurityScenarioControl controlOf(FakeSecurityPlatformDataSource fake) =>
        fake;

    test('starts as a clean device with no recording', () {
      final control = controlOf(FakeSecurityPlatformDataSource());

      expect(control.deviceScenario, DeviceScenario.clean);
      expect(control.recordingActive, isFalse);
    });

    final expectedRoot = <DeviceScenario, (String, List<String>)>{
      DeviceScenario.clean: (DetectionWire.notDetected, []),
      DeviceScenario.rooted: (
        DetectionWire.detected,
        [RootReasonCodes.suBinary, RootReasonCodes.magiskArtifacts],
      ),
      DeviceScenario.rootedWeakOnly: (
        DetectionWire.detected,
        [RootReasonCodes.testKeys],
      ),
      DeviceScenario.rootUnverifiable: (DetectionWire.unknown, []),
    };
    for (final MapEntry(key: scenario, value: (root, signals))
        in expectedRoot.entries) {
      test('${scenario.name} is what the status reports', () async {
        final fake = FakeSecurityPlatformDataSource();

        controlOf(fake).setDeviceScenario(scenario);
        final status = await fake.getSecurityStatus();

        expect(controlOf(fake).deviceScenario, scenario);
        expect(status.root, root);
        expect(status.rootSignals, signals);
      });
    }

    test('the check takes as long as the control says, and reports it', () {
      fakeAsync((async) {
        final fake = FakeSecurityPlatformDataSource();
        expect(controlOf(fake).checkDuration, Duration.zero);

        controlOf(fake).setCheckDuration(const Duration(seconds: 5));
        expect(controlOf(fake).checkDuration, const Duration(seconds: 5));
        var done = false;
        unawaited(fake.getSecurityStatus().then((_) => done = true));

        async.elapse(const Duration(seconds: 4));
        expect(done, isFalse);
        async.elapse(const Duration(seconds: 1));
        expect(done, isTrue);
      });
    });

    test('every scenario is covered by the table above', () {
      expect(expectedRoot.keys, unorderedEquals(DeviceScenario.values));
    });

    test('a recording starts and stops, and listeners hear it', () async {
      final fake = FakeSecurityPlatformDataSource();
      final seen = <String>[];
      final subscription = fake.watchScreenRecording().listen(
        (dto) => seen.add(dto.screenRecording),
      );
      await pumpEventQueue();

      controlOf(fake).setRecordingActive(active: true);
      await pumpEventQueue();
      expect(controlOf(fake).recordingActive, isTrue);
      expect(
        (await fake.getSecurityStatus()).screenRecording,
        DetectionWire.detected,
      );

      controlOf(fake).setRecordingActive(active: false);
      await pumpEventQueue();
      expect(controlOf(fake).recordingActive, isFalse);

      expect(seen, [
        DetectionWire.notDetected,
        DetectionWire.detected,
        DetectionWire.notDetected,
      ]);
      await subscription.cancel();
    });
  });

  // The simulation in the app: readings only, the window belongs to the real source.
  group('with a scripted window', () {
    Future<String> protection(FakeSecurityPlatformDataSource source) async =>
        (await source.getSecurityStatus()).windowProtection;

    test('reports protection from its script, active by default', () async {
      final source = FakeSecurityPlatformDataSource(scriptedWindow: true);

      expect(await protection(source), WindowProtectionWire.active);
      expect(source.screenProtectionAvailable, isTrue);

      source.setScreenProtectionAvailable(available: false);
      expect(await protection(source), WindowProtectionWire.inactive);

      source.setScreenProtectionAvailable(available: true);
      expect(await protection(source), WindowProtectionWire.active);
    });

    test('ignores secure window calls: it has no window to protect', () async {
      final source = FakeSecurityPlatformDataSource(scriptedWindow: true);

      await source.enableSecureWindow();
      await source.enableSecureWindow();
      await source.disableSecureWindow();

      expect(source.secureWindowCount, 0);
      expect(await protection(source), WindowProtectionWire.active);
    });

    test(
      'an enable never fails, even when protection is reported unavailable',
      () async {
        final source = FakeSecurityPlatformDataSource(scriptedWindow: true)
          ..setScreenProtectionAvailable(available: false);

        await source.enableSecureWindow();

        expect(await protection(source), WindowProtectionWire.inactive);
      },
    );

    test(
      'a whole device still reports protection from the calls it received',
      () async {
        final source = FakeSecurityPlatformDataSource();

        expect(await protection(source), WindowProtectionWire.inactive);
        await source.enableSecureWindow();
        expect(await protection(source), WindowProtectionWire.active);
      },
    );
  });
}
