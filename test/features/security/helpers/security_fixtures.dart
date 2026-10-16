import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/security/data/dtos/security_status_dto.dart';
import 'package:secure_payment_portal/features/security/domain/root_assessment.dart';
import 'package:secure_payment_portal/features/security/domain/root_signal.dart';
import 'package:secure_payment_portal/features/security/domain/security_status.dart';

const cleanDto = SecurityStatusDto(
  root: DetectionWire.notDetected,
  rootSignals: [],
  screenRecording: DetectionWire.notDetected,
  windowProtection: WindowProtectionWire.active,
);

const rootedDto = SecurityStatusDto(
  root: DetectionWire.detected,
  rootSignals: [RootReasonCodes.suBinary],
  screenRecording: DetectionWire.notDetected,
  windowProtection: WindowProtectionWire.active,
);

const cleanStatus = SecurityStatus(
  root: RootClear(),
  screenRecording: Detection.notDetected,
  windowProtection: WindowProtection.active,
);

final strongRoot = RootDetected({RootSignal.suBinary});
final weakRoot = RootDetected({
  RootSignal.testKeys,
  RootSignal.debuggableBuild,
});
