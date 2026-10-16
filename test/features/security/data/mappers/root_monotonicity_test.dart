import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/security/data/dtos/security_status_dto.dart';
import 'package:secure_payment_portal/features/security/data/mappers/security_status_mapper.dart';
import 'package:secure_payment_portal/features/security/domain/security_decision.dart';
import 'package:secure_payment_portal/features/security/domain/security_policy.dart';

void main() {
  test(
    'signals and loss of confidence never make the default policy more permissive',
    () {
      const codes = [
        RootReasonCodes.suBinary,
        RootReasonCodes.magiskArtifacts,
        RootReasonCodes.rootManagerPackage,
        RootReasonCodes.whichSu,
        RootReasonCodes.testKeys,
        RootReasonCodes.debuggableBuild,
      ];
      bool allowed(int mask, {required bool conclusive}) {
        final signals = [
          for (var i = 0; i < codes.length; i++)
            if (mask & (1 << i) != 0) codes[i],
        ];
        final status = SecurityStatusMapper.toEntity(
          SecurityStatusDto(
            root: !conclusive
                ? DetectionWire.unknown
                : signals.isEmpty
                ? DetectionWire.notDetected
                : DetectionWire.detected,
            rootSignals: signals,
            screenRecording: DetectionWire.notDetected,
            windowProtection: WindowProtectionWire.active,
          ),
        );
        return const SecurityPolicy().evaluate(status) is SecurityAllowed;
      }

      for (var mask = 0; mask < 64; mask++) {
        for (final conclusive in [true, false]) {
          final before = allowed(mask, conclusive: conclusive);
          expect(allowed(mask, conclusive: false) && !before, isFalse);
          for (var i = 0; i < codes.length; i++) {
            expect(
              allowed(mask | (1 << i), conclusive: conclusive) && !before,
              isFalse,
              reason: 'mask=$mask added=$i confidence=$conclusive',
            );
          }
        }
      }
      expect(allowed(0, conclusive: true), isTrue);
      expect(allowed(1 << 4, conclusive: true), isTrue);
      expect(allowed(1 << 4, conclusive: false), isFalse);
      expect(allowed(1, conclusive: true), isFalse);
    },
  );
}
