import 'package:equatable/equatable.dart';

enum SecurityBlockReason {
  rootDetected('security.blocked.root_detected', isRecoverable: false),
  rootUnverifiable('security.blocked.root_unverifiable', isRecoverable: false),
  screenProtectionUnavailable(
    'security.blocked.screen_protection_unavailable',
    isRecoverable: true,
  ),
  screenRecording('security.blocked.screen_recording', isRecoverable: true),
  recordingUnverifiable(
    'security.blocked.recording_unverifiable',
    isRecoverable: true,
  );

  const SecurityBlockReason(this.messageKey, {required this.isRecoverable});

  /// User-safe key for the l10n layer.
  final String messageKey;

  /// Whether the block can lift without restarting the app (a recording that
  /// ends), so the UI may wait instead of giving up.
  final bool isRecoverable;
}

/// The policy's verdict on one [SecurityStatus].
sealed class SecurityDecision extends Equatable {
  const SecurityDecision();
}

final class SecurityAllowed extends SecurityDecision {
  const SecurityAllowed();

  @override
  List<Object?> get props => [];
}

final class SecurityBlocked extends SecurityDecision {
  const SecurityBlocked(this.reason);

  final SecurityBlockReason reason;

  @override
  List<Object?> get props => [reason];
}
