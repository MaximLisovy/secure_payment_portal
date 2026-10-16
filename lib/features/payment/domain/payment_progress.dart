import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_result.dart';

/// Where processing stands. One state at a time, and the same shape whether it
/// is simulated or run by the native foreground service.
///
/// Terminal states ([PaymentSucceeded], [PaymentFailed], [PaymentCancelled])
/// stay current until the next payment starts. Equatable, so a stream of these
/// drops identical consecutive states on purpose.
sealed class PaymentProgress extends Equatable {
  const PaymentProgress();

  String? get paymentId => null;
  String? get attemptId => null;
}

/// Nothing is running and nothing has finished.
final class PaymentIdle extends PaymentProgress {
  const PaymentIdle();

  @override
  List<Object?> get props => [];
}

final class PaymentInProgress extends PaymentProgress {
  const PaymentInProgress(
    this.paymentId,
    this.percent, {
    required this.attemptId,
  }) : assert(percent >= 0 && percent <= 100, 'percent must be 0..100');

  @override
  final String paymentId;
  @override
  final String attemptId;

  /// Whole percent, 0 to 100.
  final int percent;

  double get fraction => percent / 100;

  @override
  List<Object?> get props => [paymentId, attemptId, percent];
}

final class PaymentSucceeded extends PaymentProgress {
  const PaymentSucceeded(this.result);

  final PaymentResult result;

  @override
  String get paymentId => result.paymentId;
  @override
  String get attemptId => result.attemptId;

  @override
  List<Object?> get props => [result];
}

final class PaymentFailed extends PaymentProgress {
  const PaymentFailed(this.failure, {this.paymentId, this.attemptId});

  // A transport failure may have no readable identity; it means progress is
  // unavailable, whereas a valid failed-payment event always has both IDs.
  @override
  final String? paymentId;
  @override
  final String? attemptId;

  final Failure failure;

  @override
  List<Object?> get props => [failure, paymentId, attemptId];
}

final class PaymentCancelled extends PaymentProgress {
  const PaymentCancelled({required this.paymentId, required this.attemptId});

  @override
  final String paymentId;
  @override
  final String attemptId;

  @override
  List<Object?> get props => [paymentId, attemptId];
}
