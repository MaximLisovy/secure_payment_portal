import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/features/security/domain/root_signal.dart';

/// What is known about root. "Could not tell" is its own case, not `clear`.
sealed class RootAssessment extends Equatable {
  const RootAssessment();
}

/// A strong signal fired, or all strong checks were conclusive and weak signals
/// fired. [signals] preserves observations independently of their policy weight.
final class RootDetected extends RootAssessment {
  RootDetected(Set<RootSignal> signals) : signals = Set.unmodifiable(signals);

  final Set<RootSignal> signals;

  @override
  List<Object?> get props => [signals];
}

/// All configured strong checks completed cleanly and no signals fired.
/// Weak checks may be inconclusive; this is heuristic confidence, not attestation.
final class RootClear extends RootAssessment {
  const RootClear();

  @override
  List<Object?> get props => [];
}

/// Strong-check confidence is incomplete (or the platform call failed).
/// Observed weak signals do not upgrade this uncertainty to a permitted verdict.
final class RootUnknown extends RootAssessment {
  const RootUnknown() : signals = const {};

  RootUnknown.withSignals(Set<RootSignal> signals)
    : signals = Set.unmodifiable(signals);

  final Set<RootSignal> signals;

  @override
  List<Object?> get props => [signals];
}
