import 'package:secure_payment_portal/features/security/domain/root_assessment.dart';
import 'package:secure_payment_portal/features/security/domain/security_decision.dart';
import 'package:secure_payment_portal/features/security/domain/security_status.dart';

/// When a payment may be confirmed. Pure business rule: no platform, no UI.
///
/// Root is judged first, because a rooted device will not become safe while the
/// user waits. Then comes screen protection, which the app turns on itself and
/// can try again, and last a recording, which can end on its own.
///
/// Defaults: strong root signals block, weak ones (test keys, debuggable
/// builds, common on emulators) do not; an unverifiable root blocks
/// (fail-closed); a window that is not verifiably protected blocks, for the same
/// reason; a detected recording blocks; an unverifiable recording does not
/// (there is no API for it below Android 15, and the window is protected).
final class SecurityPolicy {
  const SecurityPolicy({
    this.blockOnWeakRootSignals = false,
    this.blockOnUnknownRoot = true,
    this.blockOnUnknownRecording = false,
    this.blockOnUnprotectedWindow = true,
  });

  final bool blockOnWeakRootSignals;
  final bool blockOnUnknownRoot;
  final bool blockOnUnknownRecording;

  /// Blocks when the window is not known to be protected: switched off, could
  /// not be switched on, or impossible to tell.
  final bool blockOnUnprotectedWindow;

  SecurityDecision evaluate(SecurityStatus status) {
    switch (status.root) {
      case RootDetected(:final signals):
        if (blockOnWeakRootSignals ||
            signals.any((signal) => signal.isStrong)) {
          return const SecurityBlocked(SecurityBlockReason.rootDetected);
        }
      case RootUnknown():
        if (blockOnUnknownRoot) {
          return const SecurityBlocked(SecurityBlockReason.rootUnverifiable);
        }
      case RootClear():
        break;
    }
    if (blockOnUnprotectedWindow &&
        status.windowProtection != WindowProtection.active) {
      return const SecurityBlocked(
        SecurityBlockReason.screenProtectionUnavailable,
      );
    }
    switch (status.screenRecording) {
      case Detection.detected:
        return const SecurityBlocked(SecurityBlockReason.screenRecording);
      case Detection.unknown:
        if (blockOnUnknownRecording) {
          return const SecurityBlocked(
            SecurityBlockReason.recordingUnverifiable,
          );
        }
      case Detection.notDetected:
        break;
    }
    return const SecurityAllowed();
  }
}
