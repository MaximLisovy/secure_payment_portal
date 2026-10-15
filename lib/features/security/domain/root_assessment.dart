import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/features/security/domain/root_signal.dart';

/// What is known about root. "Could not tell" is its own case, not `clear`.
sealed class RootAssessment extends Equatable {
  const RootAssessment();
}

/// At least one heuristic fired. [signals] says which, so the policy decides
/// whether they are enough.
final class RootDetected extends RootAssessment {
  const RootDetected(this.signals);

  final Set<RootSignal> signals;

  @override
  List<Object?> get props => [signals];
}

/// Every check ran and none fired.
final class RootClear extends RootAssessment {
  const RootClear();

  @override
  List<Object?> get props => [];
}

/// The checks could not run or could not be trusted (a failed call, iOS).
final class RootUnknown extends RootAssessment {
  const RootUnknown();

  @override
  List<Object?> get props => [];
}
