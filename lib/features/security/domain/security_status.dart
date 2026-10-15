import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/features/security/domain/root_assessment.dart';

/// A platform fact that may be impossible to know. "Can't tell" is never
/// collapsed into `notDetected`.
enum Detection { detected, notDetected, unknown }

final class SecurityStatus extends Equatable {
  const SecurityStatus({required this.root, required this.screenRecording});

  /// Nothing is known. What the app falls back to when a check fails, so that
  /// the policy, not an accident, decides what an unverifiable device may do.
  static const SecurityStatus unknown = SecurityStatus(
    root: RootUnknown(),
    screenRecording: Detection.unknown,
  );

  final RootAssessment root;

  /// `detected` means a screen recording is in progress.
  final Detection screenRecording;

  SecurityStatus copyWith({RootAssessment? root, Detection? screenRecording}) {
    return SecurityStatus(
      root: root ?? this.root,
      screenRecording: screenRecording ?? this.screenRecording,
    );
  }

  @override
  List<Object?> get props => [root, screenRecording];
}
