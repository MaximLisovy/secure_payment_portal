import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/security/data/datasources/channel_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/data/repositories/security_status_repository_impl.dart';
import 'package:secure_payment_portal/features/security/domain/root_assessment.dart';
import 'package:secure_payment_portal/features/security/domain/security_status.dart';

import '../../helpers/native_security_simulator.dart';
import '../security_platform_data_source_contract.dart';

ChannelSecurityPlatformDataSource _source({
  Duration callTimeout = const Duration(seconds: 5),
}) => ChannelSecurityPlatformDataSource(
  methods: securityMethodChannel,
  recordingEvents: securityRecordingChannel,
  callTimeout: callTimeout,
);

NativeSecuritySimulator _device() {
  final device = NativeSecuritySimulator();
  addTearDown(NativeSecuritySimulator.uninstall);
  return device;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The suite the fake passes, unchanged, against the channel-based source.
  securityPlatformDataSourceContract('ChannelSecurityPlatformDataSource', () {
    _device();
    final source = _source();
    addTearDown(source.dispose);
    return source;
  });

  group('ChannelSecurityPlatformDataSource', () {
    group('getSecurityStatus', () {
      test('parses what the native side replies', () async {
        final device = _device()
          ..root = DetectionWire.detected
          ..rootSignals = [RootReasonCodes.suBinary, RootReasonCodes.testKeys]
          ..recording = DetectionWire.unknown;

        final dto = await _source().getSecurityStatus();

        expect(dto.root, DetectionWire.detected);
        expect(dto.rootSignals, [
          RootReasonCodes.suBinary,
          RootReasonCodes.testKeys,
        ]);
        expect(dto.screenRecording, DetectionWire.unknown);
        expect(dto.windowProtection, WindowProtectionWire.inactive);
        expect(device.calls, [SecurityChannel.getSecurityStatus]);
      });

      test('reports the window the native side really has protected', () async {
        _device();
        final source = _source();

        await source.enableSecureWindow();

        expect(
          (await source.getSecurityStatus()).windowProtection,
          WindowProtectionWire.active,
        );
      });

      test('a reply that is not a status is a malformed payload', () async {
        final device = _device()..malformedStatus = 'not a map';

        await expectLater(
          _source().getSecurityStatus(),
          throwsA(isA<MalformedPayloadException>()),
        );
        device.malformedStatus = {'schemaVersion': 2};
        await expectLater(
          _source().getSecurityStatus(),
          throwsA(isA<MalformedPayloadException>()),
        );
      });

      test('no native side at all is unsupported, not a crash', () async {
        // No simulator: nothing answers on the channel (iOS, plain flutter test).
        await expectLater(
          _source().getSecurityStatus(),
          throwsA(isA<UnsupportedException>()),
        );
      });
    });

    group('the secure window', () {
      test('an error reply keeps its code', () async {
        _device().hasActivity = false;

        await expectLater(
          _source().enableSecureWindow(),
          throwsA(
            isA<PlatformCallException>()
                .having((e) => e.code, 'code', ChannelErrorCodes.unavailable)
                .having((e) => e.message, 'message', isNotNull),
          ),
        );
      });

      test('a failed enable changes nothing', () async {
        final device = _device()..hasActivity = false;
        final source = _source();

        await expectLater(source.enableSecureWindow(), throwsA(anything));
        device.hasActivity = true;

        expect(device.secureCount, 0);
        expect(
          (await source.getSecurityStatus()).windowProtection,
          WindowProtectionWire.inactive,
        );
      });

      test('enable and disable reach the native side in order', () async {
        final device = _device();
        final source = _source();

        await source.enableSecureWindow();
        await source.enableSecureWindow();
        await source.disableSecureWindow();

        expect(device.secureCount, 1);
        expect(device.calls, [
          SecurityChannel.enableSecureWindow,
          SecurityChannel.enableSecureWindow,
          SecurityChannel.disableSecureWindow,
        ]);
      });

      test('no native side at all is unsupported', () async {
        await expectLater(
          _source().enableSecureWindow(),
          throwsA(isA<UnsupportedException>()),
        );
      });
    });

    group('a call that is never answered', () {
      test('fails as unavailable once the timeout passes', () {
        fakeAsync((async) {
          _device().hang = true;
          final source = _source(callTimeout: const Duration(seconds: 3));
          Object? error;
          unawaited(
            source.getSecurityStatus().then<void>(
              (_) {},
              onError: (Object e) {
                error = e;
              },
            ),
          );

          async.elapse(const Duration(seconds: 2));
          expect(error, isNull, reason: 'it may still answer');

          async.elapse(const Duration(seconds: 2));
          expect(
            error,
            isA<PlatformCallException>().having(
              (e) => e.code,
              'code',
              ChannelErrorCodes.unavailable,
            ),
          );
        });
      });

      test('the same goes for enabling the window', () {
        fakeAsync((async) {
          _device().hang = true;
          Object? error;
          unawaited(
            _source().enableSecureWindow().then<void>(
              (_) {},
              onError: (Object e) {
                error = e;
              },
            ),
          );

          async.elapse(const Duration(seconds: 6));

          expect(error, isA<PlatformCallException>());
        });
      });
    });

    group('watchScreenRecording', () {
      test('replays the current state first, then each change', () async {
        final device = _device();
        final source = _source();
        addTearDown(source.dispose);
        final seen = <String>[];
        final subscription = source.watchScreenRecording().listen(
          (dto) => seen.add(dto.screenRecording),
        );
        await pumpEventQueue();

        device.changeRecording(DetectionWire.detected);
        device.changeRecording(DetectionWire.notDetected);
        await pumpEventQueue();

        expect(seen, [
          DetectionWire.notDetected,
          DetectionWire.detected,
          DetectionWire.notDetected,
        ]);
        await subscription.cancel();
      });

      test(
        'shares one native listener between any number of listeners',
        () async {
          final device = _device();
          final source = _source();
          addTearDown(source.dispose);
          final first = <String>[];
          final second = <String>[];
          final third = <String>[];

          final a = source.watchScreenRecording().listen(
            (dto) => first.add(dto.screenRecording),
          );
          await pumpEventQueue();
          device.changeRecording(DetectionWire.detected);
          await pumpEventQueue();
          final b = source.watchScreenRecording().listen(
            (dto) => second.add(dto.screenRecording),
          );
          final c = source.watchScreenRecording().listen(
            (dto) => third.add(dto.screenRecording),
          );
          await pumpEventQueue();

          expect(
            device.listens,
            1,
            reason: 'a second native listen would replace the first',
          );
          expect(first, [DetectionWire.notDetected, DetectionWire.detected]);
          expect(second, [
            DetectionWire.detected,
          ], reason: 'a late listener is replayed');
          expect(third, [DetectionWire.detected]);

          await a.cancel();
          await b.cancel();
          await pumpEventQueue();
          expect(device.cancels, 0, reason: 'one listener is still there');

          await c.cancel();
          await pumpEventQueue();
          expect(device.cancels, 1);
        },
      );

      test(
        'reopens after the last listener left, without a stale replay',
        () async {
          final device = _device();
          final source = _source();
          addTearDown(source.dispose);
          final first = await source.watchScreenRecording().first;
          expect(first.screenRecording, DetectionWire.notDetected);
          await pumpEventQueue();

          device.recording =
              DetectionWire.detected; // changed while nobody listened
          final again = await source.watchScreenRecording().first;

          await pumpEventQueue();

          expect(again.screenRecording, DetectionWire.detected);
          expect(
            device.listens,
            2,
            reason: 'closed after the first, opened again',
          );
          expect(device.cancels, 2);
        },
      );

      test(
        'an event that is not in the documented shape reads as unknown',
        () async {
          final device = _device();
          final source = _source();
          addTearDown(source.dispose);
          final seen = <String>[];
          final subscription = source.watchScreenRecording().listen(
            (dto) => seen.add(dto.screenRecording),
          );
          await pumpEventQueue();

          device.sendRaw('garbage');
          device.sendRaw({'schemaVersion': 1});
          device.sendRaw({'schemaVersion': 1, 'screenRecording': 'detected'});
          await pumpEventQueue();

          expect(seen, [
            DetectionWire.notDetected,
            DetectionWire.unknown,
            DetectionWire.unknown,
            DetectionWire.detected,
          ]);
          await subscription.cancel();
        },
      );

      test('an error event is unknown, not an error on the stream', () async {
        final device = _device();
        final source = _source();
        addTearDown(source.dispose);
        final seen = <String>[];
        final errors = <Object>[];
        final subscription = source.watchScreenRecording().listen(
          (dto) => seen.add(dto.screenRecording),
          onError: errors.add,
        );
        await pumpEventQueue();

        device.sendError();
        device.changeRecording(DetectionWire.detected);
        await pumpEventQueue();

        expect(errors, isEmpty);
        expect(seen, [
          DetectionWire.notDetected,
          DetectionWire.unknown,
          DetectionWire.detected,
        ]);
        await subscription.cancel();
      });

      // Flutter's EventChannel does not fail the stream when `listen` fails: it
      // reports the error through FlutterError and the stream stays silent. The
      // status call still fails as unsupported, so the app reads the device as
      // unverifiable; this pins down that the recording stream neither throws nor
      // hangs its listener.
      test(
        'with no native side the stream stays silent instead of failing',
        () async {
          final source = _source();
          addTearDown(source.dispose);
          final reported = <Object>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) => reported.add(details.exception);
          addTearDown(() => FlutterError.onError = previous);
          final seen = <Object>[];
          final errors = <Object>[];

          final subscription = source.watchScreenRecording().listen(
            seen.add,
            onError: errors.add,
          );
          await pumpEventQueue();

          expect(seen, isEmpty);
          expect(errors, isEmpty);
          expect(reported.single, isA<MissingPluginException>());
          await subscription.cancel();
        },
      );

      test(
        'disposing ends the stream and closes the native listener',
        () async {
          final device = _device();
          final source = _source();
          var done = false;
          source.watchScreenRecording().listen(
            (_) {},
            onDone: () => done = true,
          );
          await pumpEventQueue();

          await source.dispose();
          await pumpEventQueue();

          expect(done, isTrue);
          expect(device.cancels, 1);
          expect(device.hasListener, isFalse);
        },
      );
    });

    group('behind the repository', () {
      test('a clean device becomes a clear status', () async {
        _device();
        final repository = SecurityStatusRepositoryImpl(_source());

        final result = await repository.getStatus();

        expect(
          result.valueOrNull,
          const SecurityStatus(
            root: RootClear(),
            screenRecording: Detection.notDetected,
            windowProtection: WindowProtection.inactive,
          ),
        );
      });

      test('no native side is an unsupported failure', () async {
        final repository = SecurityStatusRepositoryImpl(_source());

        final result = await repository.getStatus();

        expect(result, isA<Err<SecurityStatus>>());
      });

      test('watching follows a recording that starts and stops', () async {
        final device = _device();
        final source = _source();
        addTearDown(source.dispose);
        final seen = <Detection>[];
        final subscription = SecurityStatusRepositoryImpl(
          source,
        ).watchStatus().listen((status) => seen.add(status.screenRecording));
        await pumpEventQueue();

        device.changeRecording(DetectionWire.detected);
        device.changeRecording(DetectionWire.notDetected);
        await pumpEventQueue();

        expect(seen, [
          Detection.notDetected,
          Detection.detected,
          Detection.notDetected,
        ]);
        await subscription.cancel();
        await pumpEventQueue();
        expect(
          device.cancels,
          1,
          reason: 'the native listener must be released',
        );
      });
    });
  });
}
