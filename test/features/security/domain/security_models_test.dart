import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/features/security/domain/root_assessment.dart';
import 'package:secure_payment_portal/features/security/domain/root_signal.dart';
import 'package:secure_payment_portal/features/security/domain/security_decision.dart';
import 'package:secure_payment_portal/features/security/domain/security_failures.dart';
import 'package:secure_payment_portal/features/security/domain/security_status.dart';

void main() {
  group('RootSignal', () {
    test('strong signals mean root; weak ones only hint at it', () {
      expect(
        RootSignal.values.where((s) => s.isStrong),
        unorderedEquals([
          RootSignal.suBinary,
          RootSignal.magiskArtifacts,
          RootSignal.rootManagerPackage,
          RootSignal.whichSu,
          RootSignal.unrecognized,
        ]),
      );
      expect(
        RootSignal.values.where((s) => !s.isStrong),
        unorderedEquals([RootSignal.testKeys, RootSignal.debuggableBuild]),
      );
    });
  });

  group('RootAssessment', () {
    test('detected signals compare as a set, not as a list', () {
      expect(
        const RootDetected({RootSignal.testKeys, RootSignal.suBinary}),
        const RootDetected({RootSignal.suBinary, RootSignal.testKeys}),
      );
      expect(
        const RootDetected({RootSignal.testKeys}),
        isNot(const RootDetected({RootSignal.suBinary})),
      );
    });

    test('clear and unknown are different facts', () {
      expect(const RootClear(), isNot(const RootUnknown()));
      expect(const RootClear(), const RootClear());
    });

    test('a switch over it is exhaustive', () {
      String name(RootAssessment root) => switch (root) {
        RootDetected() => 'detected',
        RootClear() => 'clear',
        RootUnknown() => 'unknown',
      };

      expect(name(const RootUnknown()), 'unknown');
    });
  });

  group('SecurityStatus', () {
    test('the unknown status knows nothing', () {
      expect(SecurityStatus.unknown.root, const RootUnknown());
      expect(SecurityStatus.unknown.screenRecording, Detection.unknown);
    });

    test('copyWith changes only what is given', () {
      const status = SecurityStatus(
        root: RootClear(),
        screenRecording: Detection.notDetected,
      );

      final changed = status.copyWith(screenRecording: Detection.detected);

      expect(changed.root, const RootClear());
      expect(changed.screenRecording, Detection.detected);
      expect(status.copyWith(), status);
    });
  });

  group('SecurityBlockReason', () {
    test('has a unique message key per reason', () {
      final keys = SecurityBlockReason.values.map((r) => r.messageKey).toList();

      expect(keys.toSet(), hasLength(keys.length));
      expect(keys, everyElement(startsWith('security.blocked.')));
    });

    test('only a recording can lift without restarting the app', () {
      expect(SecurityBlockReason.screenRecording.isRecoverable, isTrue);
      expect(SecurityBlockReason.recordingUnverifiable.isRecoverable, isTrue);
      expect(SecurityBlockReason.rootDetected.isRecoverable, isFalse);
      expect(SecurityBlockReason.rootUnverifiable.isRecoverable, isFalse);
    });
  });

  group('SecurityBlockedFailure', () {
    test('uses the reason message key and compares by reason', () {
      final failure = SecurityBlockedFailure(SecurityBlockReason.rootDetected);

      expect(failure.messageKey, 'security.blocked.root_detected');
      expect(failure, SecurityBlockedFailure(SecurityBlockReason.rootDetected));
      expect(
        failure,
        isNot(SecurityBlockedFailure(SecurityBlockReason.screenRecording)),
      );
      expect(failure, isA<Failure>());
    });

    test('a switch over SecurityFailure is exhaustive', () {
      String describe(SecurityFailure failure) => switch (failure) {
        SecurityBlockedFailure(:final reason) => reason.name,
      };

      expect(
        describe(SecurityBlockedFailure(SecurityBlockReason.screenRecording)),
        'screenRecording',
      );
    });
  });
}
