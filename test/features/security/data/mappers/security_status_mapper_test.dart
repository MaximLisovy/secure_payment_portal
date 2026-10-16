import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/security/data/dtos/security_status_dto.dart';
import 'package:secure_payment_portal/features/security/data/mappers/security_status_mapper.dart';
import 'package:secure_payment_portal/features/security/domain/root_assessment.dart';
import 'package:secure_payment_portal/features/security/domain/root_signal.dart';
import 'package:secure_payment_portal/features/security/domain/security_status.dart';

import '../../helpers/security_fixtures.dart';

SecurityStatusDto _dto({
  String root = DetectionWire.notDetected,
  List<String> signals = const [],
  String recording = DetectionWire.notDetected,
  String window = WindowProtectionWire.active,
}) => SecurityStatusDto(
  root: root,
  rootSignals: signals,
  screenRecording: recording,
  windowProtection: window,
);

Matcher get _malformed => throwsA(isA<MalformedPayloadException>());

void main() {
  group('SecurityStatusMapper.toEntity', () {
    test('maps a clean device', () {
      expect(SecurityStatusMapper.toEntity(cleanDto), cleanStatus);
    });

    test('maps detected root with its signals', () {
      final status = SecurityStatusMapper.toEntity(
        _dto(
          root: DetectionWire.detected,
          signals: [RootReasonCodes.suBinary, RootReasonCodes.testKeys],
        ),
      );

      expect(
        status.root,
        RootDetected({RootSignal.suBinary, RootSignal.testKeys}),
      );
    });

    test('maps an unverifiable root and recording without guessing', () {
      final status = SecurityStatusMapper.toEntity(
        _dto(
          root: DetectionWire.unknown,
          recording: DetectionWire.unknown,
          window: WindowProtectionWire.unknown,
        ),
      );

      expect(status, SecurityStatus.unknown);
    });

    test('unknown confidence retains weak signals immutably', () {
      final root =
          SecurityStatusMapper.toEntity(
                _dto(
                  root: DetectionWire.unknown,
                  signals: [RootReasonCodes.testKeys],
                ),
              ).root
              as RootUnknown;
      expect(root.signals, {RootSignal.testKeys});
      expect(() => root.signals.clear(), throwsUnsupportedError);
    });

    test('maps a detected recording', () {
      final status = SecurityStatusMapper.toEntity(
        _dto(recording: DetectionWire.detected),
      );

      expect(status.screenRecording, Detection.detected);
    });

    test('maps every window protection value', () {
      for (final (wire, expected) in [
        (WindowProtectionWire.active, WindowProtection.active),
        (WindowProtectionWire.inactive, WindowProtection.inactive),
        (WindowProtectionWire.unknown, WindowProtection.unknown),
      ]) {
        expect(
          SecurityStatusMapper.toEntity(_dto(window: wire)).windowProtection,
          expected,
        );
      }
    });

    test('rejects a window protection value it does not know', () {
      expect(
        () => SecurityStatusMapper.toEntity(_dto(window: 'maybe')),
        _malformed,
      );
    });

    test('rejects a root that contradicts its signals', () {
      expect(
        () => SecurityStatusMapper.toEntity(_dto(root: DetectionWire.detected)),
        _malformed,
      );
      expect(
        () => SecurityStatusMapper.toEntity(
          _dto(signals: [RootReasonCodes.suBinary]),
        ),
        _malformed,
      );
    });

    test('rejects a detection value it does not know', () {
      expect(
        () => SecurityStatusMapper.toEntity(_dto(root: 'maybe')),
        _malformed,
      );
      expect(
        () => SecurityStatusMapper.toEntity(_dto(recording: 'maybe')),
        _malformed,
      );
    });
  });

  group('SecurityStatusMapper.rootSignalFromCode', () {
    test('maps every documented reason code', () {
      expect(
        {
          RootReasonCodes.suBinary: RootSignal.suBinary,
          RootReasonCodes.magiskArtifacts: RootSignal.magiskArtifacts,
          RootReasonCodes.rootManagerPackage: RootSignal.rootManagerPackage,
          RootReasonCodes.whichSu: RootSignal.whichSu,
          RootReasonCodes.testKeys: RootSignal.testKeys,
          RootReasonCodes.debuggableBuild: RootSignal.debuggableBuild,
        }.entries.every(
          (entry) =>
              SecurityStatusMapper.rootSignalFromCode(entry.key) == entry.value,
        ),
        isTrue,
      );
    });

    test(
      'keeps a code it does not know as a strong signal, never drops it',
      () {
        final signal = SecurityStatusMapper.rootSignalFromCode(
          'some_new_check',
        );

        expect(signal, RootSignal.unrecognized);
        expect(signal.isStrong, isTrue);
      },
    );

    test('maps unknown codes inside a detected root', () {
      final status = SecurityStatusMapper.toEntity(
        _dto(root: DetectionWire.detected, signals: ['some_new_check']),
      );

      expect(status.root, RootDetected({RootSignal.unrecognized}));
    });
  });

  group('SecurityStatusMapper.detectionFromWire', () {
    test('maps the three wire values', () {
      expect(
        SecurityStatusMapper.detectionFromWire(DetectionWire.detected),
        Detection.detected,
      );
      expect(
        SecurityStatusMapper.detectionFromWire(DetectionWire.notDetected),
        Detection.notDetected,
      );
      expect(
        SecurityStatusMapper.detectionFromWire(DetectionWire.unknown),
        Detection.unknown,
      );
    });

    test('rejects anything else, including a different case', () {
      expect(
        () => SecurityStatusMapper.detectionFromWire('DETECTED'),
        _malformed,
      );
      expect(() => SecurityStatusMapper.detectionFromWire(''), _malformed);
    });
  });
}
