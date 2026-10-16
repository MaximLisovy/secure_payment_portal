import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/core/logging/logger.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/security/data/datasources/security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/data/dtos/screen_recording_dto.dart';
import 'package:secure_payment_portal/features/security/data/dtos/security_status_dto.dart';
import 'package:secure_payment_portal/features/security/data/repositories/security_status_repository_impl.dart';
import 'package:secure_payment_portal/features/security/domain/root_assessment.dart';
import 'package:secure_payment_portal/features/security/domain/security_status.dart';

import '../../helpers/security_fixtures.dart';

class _MockDataSource extends Mock implements SecurityPlatformDataSource {}

ScreenRecordingDto _recording(String wire) =>
    ScreenRecordingDto(screenRecording: wire);

void main() {
  late _MockDataSource dataSource;
  late SecurityStatusRepositoryImpl repository;

  setUp(() {
    dataSource = _MockDataSource();
    repository = SecurityStatusRepositoryImpl(
      dataSource,
      logger: const SilentLogger(),
    );
  });

  group('getStatus', () {
    test('maps the DTO to a status', () async {
      when(
        () => dataSource.getSecurityStatus(),
      ).thenAnswer((_) async => rootedDto);

      final result = await repository.getStatus();

      expect(result.valueOrNull?.root, strongRoot);
    });

    final failures = <(String, DataSourceException, Failure)>[
      ('network', const NetworkException(), const NetworkFailure()),
      ('not found', const NotFoundException(), const NotFoundFailure()),
      (
        'platform error',
        const PlatformCallException(ChannelErrorCodes.internal),
        const PlatformFailure(ChannelErrorCodes.internal),
      ),
      ('unsupported', const UnsupportedException(), const UnsupportedFailure()),
      (
        'malformed payload',
        const MalformedPayloadException('x'),
        const InvalidDataFailure(),
      ),
    ];
    for (final (name, thrown, expected) in failures) {
      test('maps a $name exception to $expected', () async {
        when(() => dataSource.getSecurityStatus()).thenThrow(thrown);

        expect(await repository.getStatus(), Err<SecurityStatus>(expected));
      });
    }

    test('a contradictory payload becomes InvalidDataFailure', () async {
      when(() => dataSource.getSecurityStatus()).thenAnswer(
        (_) async => const SecurityStatusDto(
          root: DetectionWire.detected,
          rootSignals: [],
          screenRecording: DetectionWire.notDetected,
          windowProtection: WindowProtectionWire.active,
        ),
      );

      expect(
        await repository.getStatus(),
        const Err<SecurityStatus>(InvalidDataFailure()),
      );
    });

    test('maps an unexpected exception to a typed failure', () async {
      when(() => dataSource.getSecurityStatus()).thenThrow(StateError('bug'));

      expect(
        (await repository.getStatus()).failureOrNull,
        const UnexpectedFailure(),
      );
    });
  });

  group('watchStatus', () {
    late StreamController<ScreenRecordingDto> recording;
    late List<SecurityStatus> emitted;
    late bool done;
    StreamSubscription<SecurityStatus>? subscription;

    setUp(() {
      recording = StreamController<ScreenRecordingDto>();
      emitted = [];
      done = false;
      when(
        () => dataSource.watchScreenRecording(),
      ).thenAnswer((_) => recording.stream);
    });

    tearDown(() async {
      await subscription?.cancel();
      await recording.close();
    });

    Future<void> start() async {
      subscription = repository.watchStatus().listen(
        emitted.add,
        onDone: () => done = true,
      );
      await pumpEventQueue();
    }

    test('starts with one fresh status', () async {
      when(
        () => dataSource.getSecurityStatus(),
      ).thenAnswer((_) async => cleanDto);

      await start();

      expect(emitted, [cleanStatus]);
      verify(() => dataSource.getSecurityStatus()).called(1);
    });

    test('emits the status again when the recording state changes', () async {
      when(
        () => dataSource.getSecurityStatus(),
      ).thenAnswer((_) async => cleanDto);
      await start();

      recording.add(_recording(DetectionWire.detected));
      await pumpEventQueue();
      recording.add(_recording(DetectionWire.notDetected));
      await pumpEventQueue();

      expect(emitted.map((s) => s.screenRecording), [
        Detection.notDetected,
        Detection.detected,
        Detection.notDetected,
      ]);
      expect(emitted.every((s) => s.root == const RootClear()), isTrue);
    });

    test('does not repeat a state that did not change', () async {
      when(
        () => dataSource.getSecurityStatus(),
      ).thenAnswer((_) async => cleanDto);
      await start();

      // The data source replays the current state on listen: no new status.
      recording.add(_recording(DetectionWire.notDetected));
      await pumpEventQueue();

      expect(emitted, [cleanStatus]);
    });

    test(
      'a recording that started during the first read is not lost',
      () async {
        when(
          () => dataSource.getSecurityStatus(),
        ).thenAnswer((_) async => cleanDto);
        // Replay on listen delivers the newer state right away.
        recording.add(_recording(DetectionWire.detected));

        await start();

        expect(emitted.map((s) => s.screenRecording), [
          Detection.notDetected,
          Detection.detected,
        ]);
      },
    );

    test(
      'a failed first read starts as unknown and keeps root unknown',
      () async {
        when(
          () => dataSource.getSecurityStatus(),
        ).thenThrow(const NetworkException());
        await start();

        recording.add(_recording(DetectionWire.detected));
        await pumpEventQueue();

        expect(emitted, [
          SecurityStatus.unknown,
          SecurityStatus.unknown.copyWith(screenRecording: Detection.detected),
        ]);
      },
    );

    test(
      'an error event turns the recording state unknown, not an error',
      () async {
        when(
          () => dataSource.getSecurityStatus(),
        ).thenAnswer((_) async => cleanDto);
        await start();

        recording.addError(
          const PlatformCallException(ChannelErrorCodes.internal),
        );
        await pumpEventQueue();

        expect(emitted.last.screenRecording, Detection.unknown);
      },
    );

    test('a malformed event turns the recording state unknown', () async {
      when(
        () => dataSource.getSecurityStatus(),
      ).thenAnswer((_) async => cleanDto);
      await start();

      recording.add(_recording('gibberish'));
      await pumpEventQueue();

      expect(emitted.last.screenRecording, Detection.unknown);
    });

    test('stops listening to the data source when cancelled', () async {
      when(
        () => dataSource.getSecurityStatus(),
      ).thenAnswer((_) async => cleanDto);
      await start();
      expect(recording.hasListener, isTrue);

      await subscription?.cancel();

      expect(recording.hasListener, isFalse);
    });

    test('completes when the data source stream completes', () async {
      when(
        () => dataSource.getSecurityStatus(),
      ).thenAnswer((_) async => cleanDto);
      await start();

      await recording.close();
      await pumpEventQueue();

      expect(done, isTrue);
    });
  });
}
