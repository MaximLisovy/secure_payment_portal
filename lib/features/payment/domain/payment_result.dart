import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/core/domain/money.dart';

/// The receipt of a payment that went through.
final class PaymentResult extends Equatable {
  const PaymentResult({
    required this.paymentId,
    required this.transactionId,
    required this.amount,
    required this.completedAt,
  });

  final String paymentId;
  final String transactionId;
  final Money amount;
  final DateTime completedAt;

  @override
  List<Object?> get props => [paymentId, transactionId, amount, completedAt];
}
