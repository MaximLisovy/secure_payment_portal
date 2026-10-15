import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/security/data/dtos/security_status_dto.dart';
import 'package:secure_payment_portal/features/security/domain/root_assessment.dart';
import 'package:secure_payment_portal/features/security/domain/root_signal.dart';
import 'package:secure_payment_portal/features/security/domain/security_status.dart';

/// DTO → entity. Anything that contradicts itself throws a
/// [MalformedPayloadException]; the repository turns that into a failure, and
/// the policy then treats the status as unknown rather than guessing.
abstract final class SecurityStatusMapper {
  static SecurityStatus toEntity(SecurityStatusDto dto) {
    return SecurityStatus(
      root: _rootFrom(dto.root, dto.rootSignals),
      screenRecording: detectionFromWire(dto.screenRecording),
      windowProtection: windowProtectionFromWire(dto.windowProtection),
    );
  }

  static WindowProtection windowProtectionFromWire(String wire) {
    return switch (wire) {
      WindowProtectionWire.active => WindowProtection.active,
      WindowProtectionWire.inactive => WindowProtection.inactive,
      WindowProtectionWire.unknown => WindowProtection.unknown,
      _ => throw const MalformedPayloadException(
        'unknown window protection value in a security payload',
      ),
    };
  }

  static Detection detectionFromWire(String wire) {
    return switch (wire) {
      DetectionWire.detected => Detection.detected,
      DetectionWire.notDetected => Detection.notDetected,
      DetectionWire.unknown => Detection.unknown,
      _ => throw const MalformedPayloadException(
        'unknown detection value in a security payload',
      ),
    };
  }

  /// A code from a newer native check maps to [RootSignal.unrecognized], which
  /// is strong, so it is never dropped.
  static RootSignal rootSignalFromCode(String code) {
    return switch (code) {
      RootReasonCodes.suBinary => RootSignal.suBinary,
      RootReasonCodes.magiskArtifacts => RootSignal.magiskArtifacts,
      RootReasonCodes.rootManagerPackage => RootSignal.rootManagerPackage,
      RootReasonCodes.whichSu => RootSignal.whichSu,
      RootReasonCodes.testKeys => RootSignal.testKeys,
      RootReasonCodes.debuggableBuild => RootSignal.debuggableBuild,
      _ => RootSignal.unrecognized,
    };
  }

  static RootAssessment _rootFrom(String state, List<String> codes) {
    final detection = detectionFromWire(state);
    switch (detection) {
      case Detection.detected:
        if (codes.isEmpty) {
          throw const MalformedPayloadException(
            'root is detected but no signal says why',
          );
        }
        return RootDetected(codes.map(rootSignalFromCode).toSet());
      case Detection.notDetected:
        _requireNoSignals(codes);
        return const RootClear();
      case Detection.unknown:
        _requireNoSignals(codes);
        return const RootUnknown();
    }
  }

  static void _requireNoSignals(List<String> codes) {
    if (codes.isNotEmpty) {
      throw const MalformedPayloadException(
        'root signals reported although root is not detected',
      );
    }
  }
}
