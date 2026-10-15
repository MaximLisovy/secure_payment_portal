import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/security/data/dtos/screen_recording_dto.dart';
import 'package:secure_payment_portal/features/security/data/dtos/security_status_dto.dart';

import '../../helpers/security_fixtures.dart';

Matcher get _malformed => throwsA(isA<MalformedPayloadException>());

// What a MethodChannel reply looks like after decoding.
Map<Object?, Object?> _statusMap({
  Object? version = ChannelContract.schemaVersion,
  Object? root = DetectionWire.notDetected,
  Object? signals = const <Object?>[],
  Object? recording = DetectionWire.notDetected,
}) => <Object?, Object?>{
  ChannelContract.keySchemaVersion: version,
  SecurityChannel.keyRoot: root,
  SecurityChannel.keyRootSignals: signals,
  SecurityChannel.keyScreenRecording: recording,
};

void main() {
  group('SecurityStatusDto.fromMap', () {
    test('reads the documented shape', () {
      final dto = SecurityStatusDto.fromMap(
        _statusMap(
          root: DetectionWire.detected,
          signals: <Object?>[
            RootReasonCodes.suBinary,
            RootReasonCodes.testKeys,
          ],
          recording: DetectionWire.unknown,
        ),
      );

      expect(dto.root, DetectionWire.detected);
      expect(dto.rootSignals, [
        RootReasonCodes.suBinary,
        RootReasonCodes.testKeys,
      ]);
      expect(dto.screenRecording, DetectionWire.unknown);
    });

    test('round-trips through toMap', () {
      expect(SecurityStatusDto.fromMap(rootedDto.toMap()), rootedDto);
      expect(SecurityStatusDto.fromMap(cleanDto.toMap()), cleanDto);
    });

    test('toMap writes the schema version', () {
      expect(
        cleanDto.toMap()[ChannelContract.keySchemaVersion],
        ChannelContract.schemaVersion,
      );
    });

    test('rejects anything that is not the documented shape', () {
      expect(() => SecurityStatusDto.fromMap(null), _malformed);
      expect(() => SecurityStatusDto.fromMap('detected'), _malformed);
      expect(
        () => SecurityStatusDto.fromMap(_statusMap(version: 2)),
        _malformed,
      );
      expect(
        () => SecurityStatusDto.fromMap(_statusMap(version: null)),
        _malformed,
      );
      expect(() => SecurityStatusDto.fromMap(_statusMap(root: 1)), _malformed);
      expect(
        () => SecurityStatusDto.fromMap(_statusMap(recording: null)),
        _malformed,
      );
      expect(
        () => SecurityStatusDto.fromMap(_statusMap(signals: 'su')),
        _malformed,
      );
      expect(
        () =>
            SecurityStatusDto.fromMap(_statusMap(signals: <Object?>['su', 3])),
        _malformed,
      );
    });

    test('does not validate meaning: that is the mapper\'s job', () {
      // An unknown detection string is structurally fine.
      expect(
        SecurityStatusDto.fromMap(_statusMap(root: 'maybe')).root,
        'maybe',
      );
    });
  });

  group('ScreenRecordingDto.fromMap', () {
    test('reads and round-trips an event', () {
      const dto = ScreenRecordingDto(screenRecording: DetectionWire.detected);

      expect(ScreenRecordingDto.fromMap(dto.toMap()), dto);
    });

    test('rejects a malformed event', () {
      expect(() => ScreenRecordingDto.fromMap(null), _malformed);
      expect(
        () => ScreenRecordingDto.fromMap(<Object?, Object?>{}),
        _malformed,
      );
      expect(
        () => ScreenRecordingDto.fromMap(<Object?, Object?>{
          ChannelContract.keySchemaVersion: ChannelContract.schemaVersion,
          SecurityChannel.keyScreenRecording: true,
        }),
        _malformed,
      );
      expect(
        () => ScreenRecordingDto.fromMap(<Object?, Object?>{
          ChannelContract.keySchemaVersion: 9,
          SecurityChannel.keyScreenRecording: DetectionWire.detected,
        }),
        _malformed,
      );
    });
  });
}
