import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/features/security/domain/root_assessment.dart';
import 'package:secure_payment_portal/features/security/domain/root_signal.dart';
import 'package:secure_payment_portal/features/security/domain/security_decision.dart';
import 'package:secure_payment_portal/features/security/domain/security_policy.dart';
import 'package:secure_payment_portal/features/security/domain/security_status.dart';

import '../helpers/security_fixtures.dart';

const _allowed = SecurityAllowed();
const _rootDetected = SecurityBlocked(SecurityBlockReason.rootDetected);
const _rootUnverifiable = SecurityBlocked(SecurityBlockReason.rootUnverifiable);
const _recording = SecurityBlocked(SecurityBlockReason.screenRecording);
const _recordingUnverifiable = SecurityBlocked(
  SecurityBlockReason.recordingUnverifiable,
);

SecurityStatus _status(RootAssessment root, Detection recording) =>
    SecurityStatus(root: root, screenRecording: recording);

void main() {
  group('SecurityPolicy defaults', () {
    const policy = SecurityPolicy();

    // root x recording -> decision. Root is judged first.
    const cases = <(String, RootAssessment, Detection, SecurityDecision)>[
      (
        'strong root, no recording',
        strongRoot,
        Detection.notDetected,
        _rootDetected,
      ),
      ('strong root, recording', strongRoot, Detection.detected, _rootDetected),
      (
        'strong root, recording unknown',
        strongRoot,
        Detection.unknown,
        _rootDetected,
      ),
      (
        'weak and strong signals together',
        RootDetected({RootSignal.testKeys, RootSignal.magiskArtifacts}),
        Detection.notDetected,
        _rootDetected,
      ),
      (
        'a signal this app version does not know',
        RootDetected({RootSignal.unrecognized}),
        Detection.notDetected,
        _rootDetected,
      ),
      (
        'weak signals only, no recording',
        weakRoot,
        Detection.notDetected,
        _allowed,
      ),
      (
        'weak signals only, recording unknown',
        weakRoot,
        Detection.unknown,
        _allowed,
      ),
      (
        'weak signals only, recording',
        weakRoot,
        Detection.detected,
        _recording,
      ),
      (
        'root unknown, no recording',
        RootUnknown(),
        Detection.notDetected,
        _rootUnverifiable,
      ),
      (
        'root unknown, recording',
        RootUnknown(),
        Detection.detected,
        _rootUnverifiable,
      ),
      ('root clear, recording', RootClear(), Detection.detected, _recording),
      (
        'root clear, recording unknown',
        RootClear(),
        Detection.unknown,
        _allowed,
      ),
      (
        'root clear, no recording',
        RootClear(),
        Detection.notDetected,
        _allowed,
      ),
    ];

    for (final (name, root, recording, expected) in cases) {
      test('$name -> $expected', () {
        expect(policy.evaluate(_status(root, recording)), expected);
      });
    }

    test('a status nobody could read is blocked (fail-closed)', () {
      expect(policy.evaluate(SecurityStatus.unknown), _rootUnverifiable);
    });
  });

  group('SecurityPolicy configuration', () {
    test('can block weak root signals too', () {
      const policy = SecurityPolicy(blockOnWeakRootSignals: true);

      expect(
        policy.evaluate(_status(weakRoot, Detection.notDetected)),
        _rootDetected,
      );
      expect(
        policy.evaluate(_status(strongRoot, Detection.notDetected)),
        _rootDetected,
      );
      expect(policy.evaluate(cleanStatus), _allowed);
    });

    test('can allow an unverifiable root, and recording is still judged', () {
      const policy = SecurityPolicy(blockOnUnknownRoot: false);

      expect(
        policy.evaluate(_status(const RootUnknown(), Detection.notDetected)),
        _allowed,
      );
      expect(
        policy.evaluate(_status(const RootUnknown(), Detection.detected)),
        _recording,
      );
    });

    test('can block an unverifiable screen recording state', () {
      const policy = SecurityPolicy(blockOnUnknownRecording: true);

      expect(
        policy.evaluate(_status(const RootClear(), Detection.unknown)),
        _recordingUnverifiable,
      );
      expect(
        policy.evaluate(_status(weakRoot, Detection.unknown)),
        _recordingUnverifiable,
      );
      expect(policy.evaluate(cleanStatus), _allowed);
    });

    test('a detected recording blocks whatever the configuration says', () {
      const lenient = SecurityPolicy(blockOnUnknownRoot: false);

      expect(
        lenient.evaluate(_status(const RootClear(), Detection.detected)),
        _recording,
      );
    });
  });
}
