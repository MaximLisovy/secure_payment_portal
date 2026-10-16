import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_result.dart';
import 'package:secure_payment_portal/features/security/security_domain.dart';

/// The three screens the flow can be on. The page swaps between them.
enum PaymentFlowPhase { review, processing, checking, result }

/// Where the payment flow stands. One state at a time.
sealed class PaymentFlowState extends Equatable {
  const PaymentFlowState();

  PaymentFlowPhase get phase;
}

/// Nothing has started: the bill is not loaded yet.
final class PaymentFlowIdle extends PaymentFlowState {
  const PaymentFlowIdle();

  @override
  PaymentFlowPhase get phase => PaymentFlowPhase.review;

  @override
  List<Object?> get props => [];
}

/// Reading the device's security status.
final class PaymentFlowSecurityCheck extends PaymentFlowState {
  const PaymentFlowSecurityCheck();

  @override
  PaymentFlowPhase get phase => PaymentFlowPhase.review;

  @override
  List<Object?> get props => [];
}

/// The policy refuses payment on this device right now.
final class PaymentFlowBlocked extends PaymentFlowState {
  const PaymentFlowBlocked(this.reason);

  final SecurityBlockReason reason;

  @override
  PaymentFlowPhase get phase => PaymentFlowPhase.review;

  @override
  List<Object?> get props => [reason];
}

/// The device passed the check; the user may confirm.
final class PaymentFlowReady extends PaymentFlowState {
  const PaymentFlowReady();

  @override
  PaymentFlowPhase get phase => PaymentFlowPhase.review;

  @override
  List<Object?> get props => [];
}

/// Confirm was pressed: the device is being checked once more and processing
/// is starting.
final class PaymentFlowConfirming extends PaymentFlowState {
  const PaymentFlowConfirming();

  @override
  PaymentFlowPhase get phase => PaymentFlowPhase.review;

  @override
  List<Object?> get props => [];
}

final class PaymentFlowProcessing extends PaymentFlowState {
  const PaymentFlowProcessing({
    required this.percent,
    this.cancelRequested = false,
    this.cancellationFailure,
  });

  /// Whole percent, 0 to 100.
  final int percent;

  /// Cancel was pressed and the platform has not confirmed it yet.
  final bool cancelRequested;

  /// A rejected cancel leaves processing active and offers a retry.
  final Failure? cancellationFailure;

  PaymentFlowProcessing copyWith({
    int? percent,
    bool? cancelRequested,
    Failure? cancellationFailure,
    bool clearCancellationFailure = false,
  }) {
    return PaymentFlowProcessing(
      percent: percent ?? this.percent,
      cancelRequested: cancelRequested ?? this.cancelRequested,
      cancellationFailure: clearCancellationFailure
          ? null
          : cancellationFailure ?? this.cancellationFailure,
    );
  }

  @override
  PaymentFlowPhase get phase => PaymentFlowPhase.processing;

  @override
  List<Object?> get props => [percent, cancelRequested, cancellationFailure];
}

final class PaymentFlowSuccess extends PaymentFlowState {
  const PaymentFlowSuccess(this.result);

  final PaymentResult result;

  @override
  PaymentFlowPhase get phase => PaymentFlowPhase.result;

  @override
  List<Object?> get props => [result];
}

final class PaymentFlowFailure extends PaymentFlowState {
  const PaymentFlowFailure(this.failure);

  final Failure failure;

  @override
  PaymentFlowPhase get phase => PaymentFlowPhase.result;

  @override
  List<Object?> get props => [failure];
}

final class PaymentFlowCancelled extends PaymentFlowState {
  const PaymentFlowCancelled();

  @override
  PaymentFlowPhase get phase => PaymentFlowPhase.result;

  @override
  List<Object?> get props => [];
}

/// An accepted attempt may still be running. Expiry changes the guidance, never
/// enables a payment retry; late terminal events can still resolve the attempt.
final class PaymentFlowCheckingStatus extends PaymentFlowState {
  const PaymentFlowCheckingStatus({
    this.expired = false,
    this.cancelRequested = false,
    this.cancellationFailure,
  });

  final bool expired;
  final bool cancelRequested;
  final Failure? cancellationFailure;

  PaymentFlowCheckingStatus copyWith({
    bool? expired,
    bool? cancelRequested,
    Failure? cancellationFailure,
    bool clearCancellationFailure = false,
  }) => PaymentFlowCheckingStatus(
    expired: expired ?? this.expired,
    cancelRequested: cancelRequested ?? this.cancelRequested,
    cancellationFailure: clearCancellationFailure
        ? null
        : cancellationFailure ?? this.cancellationFailure,
  );

  @override
  PaymentFlowPhase get phase => PaymentFlowPhase.checking;
  @override
  List<Object?> get props => [expired, cancelRequested, cancellationFailure];
}
