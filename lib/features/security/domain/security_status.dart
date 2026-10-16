import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/features/security/domain/root_assessment.dart';

/// A platform fact that may be impossible to know. "Can't tell" is never
/// collapsed into `notDetected`.
enum Detection { detected, notDetected, unknown }

/// Whether the app window is hidden from screenshots and screen recording
/// right now. Unlike root, this is something the app turns on itself, so
/// "could not turn it on" and "cannot tell" are as much a risk as "off".
enum WindowProtection { active, inactive, unknown }

final class SecurityStatus extends Equatable {
  const SecurityStatus({
    required this.root,
    required this.screenRecording,
    required this.windowProtection,
  });

  /// Nothing is known. What the app falls back to when a check fails, so that
  /// the policy, not an accident, decides what an unverifiable device may do.
  static const SecurityStatus unknown = SecurityStatus(
    root: RootUnknown(),
    screenRecording: Detection.unknown,
    windowProtection: WindowProtection.unknown,
  );

  final RootAssessment root;

  /// `detected` means this app is reported visible in a recording (API 35+).
  /// `notDetected` does not prove that no recorder is active.
  final Detection screenRecording;

  final WindowProtection windowProtection;

  SecurityStatus copyWith({
    RootAssessment? root,
    Detection? screenRecording,
    WindowProtection? windowProtection,
  }) {
    return SecurityStatus(
      root: root ?? this.root,
      screenRecording: screenRecording ?? this.screenRecording,
      windowProtection: windowProtection ?? this.windowProtection,
    );
  }

  @override
  List<Object?> get props => [root, screenRecording, windowProtection];
}
