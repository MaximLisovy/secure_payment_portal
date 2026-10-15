import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';

import '../../helpers/security_fixtures.dart';
import '../security_platform_data_source_contract.dart';

void main() {
  securityPlatformDataSourceContract(
    'FakeSecurityPlatformDataSource',
    FakeSecurityPlatformDataSource.new,
  );

  group('FakeSecurityPlatformDataSource', () {
    test('is a clean device by default', () async {
      final status = await FakeSecurityPlatformDataSource().getSecurityStatus();

      expect(status, cleanDto);
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
        expect(await source.getSecurityStatus(), cleanDto);
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

    testWidgets('getSecurityStatus takes exactly the configured latency', (
      tester,
    ) async {
      final source = FakeSecurityPlatformDataSource(
        latency: const Duration(seconds: 2),
      );
      var done = false;
      unawaited(source.getSecurityStatus().then((_) => done = true));

      await tester.pump(const Duration(seconds: 1));
      expect(done, isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(done, isTrue);
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
}
