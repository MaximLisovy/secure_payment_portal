import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/core/platform/wire_reader.dart';

/// One event of the payment progress `EventChannel`. Which fields are present
/// depends on [state]; `fromMap` enforces that, and the mapper checks values.
final class PaymentProgressDto extends Equatable {
  const PaymentProgressDto({
    required this.state,
    this.paymentId,
    this.attemptId,
    this.percent,
    this.transactionId,
    this.amountMinor,
    this.currency,
    this.completedAtMillis,
    this.errorCode,
  });

  const PaymentProgressDto.running(
    String paymentId,
    int percent, {
    required String attemptId,
  }) : this(
         state: PaymentChannel.stateRunning,
         paymentId: paymentId,
         attemptId: attemptId,
         percent: percent,
       );

  const PaymentProgressDto.succeeded({
    required String paymentId,
    required String attemptId,
    required String transactionId,
    required int amountMinor,
    required String currency,
    required int completedAtMillis,
  }) : this(
         state: PaymentChannel.stateSucceeded,
         paymentId: paymentId,
         attemptId: attemptId,
         transactionId: transactionId,
         amountMinor: amountMinor,
         currency: currency,
         completedAtMillis: completedAtMillis,
       );

  const PaymentProgressDto.failed(
    String errorCode, {
    required String paymentId,
    required String attemptId,
  }) : this(
         state: PaymentChannel.stateFailed,
         errorCode: errorCode,
         paymentId: paymentId,
         attemptId: attemptId,
       );

  static const PaymentProgressDto idle = PaymentProgressDto(
    state: PaymentChannel.stateIdle,
  );

  const PaymentProgressDto.cancelled({
    required String paymentId,
    required String attemptId,
  }) : this(
         state: PaymentChannel.stateCancelled,
         paymentId: paymentId,
         attemptId: attemptId,
       );

  /// Throws `MalformedPayloadException` if [raw] is not the documented shape.
  factory PaymentProgressDto.fromMap(Object? raw) {
    final reader = WireReader(raw, what: 'payment progress')
      ..requireSchemaVersion();
    final state = reader.requireString(PaymentChannel.keyState);
    switch (state) {
      case PaymentChannel.stateIdle:
        return PaymentProgressDto(state: state);
      case PaymentChannel.stateCancelled:
        return PaymentProgressDto.cancelled(
          paymentId: reader.requireString(PaymentChannel.keyPaymentId),
          attemptId: reader.requireString(PaymentChannel.keyAttemptId),
        );
      case PaymentChannel.stateRunning:
        return PaymentProgressDto.running(
          reader.requireString(PaymentChannel.keyPaymentId),
          reader.requireInt(PaymentChannel.keyPercent),
          attemptId: reader.requireString(PaymentChannel.keyAttemptId),
        );
      case PaymentChannel.stateSucceeded:
        return PaymentProgressDto.succeeded(
          paymentId: reader.requireString(PaymentChannel.keyPaymentId),
          attemptId: reader.requireString(PaymentChannel.keyAttemptId),
          transactionId: reader.requireString(PaymentChannel.keyTransactionId),
          amountMinor: reader.requireInt(PaymentChannel.keyAmountMinor),
          currency: reader.requireString(PaymentChannel.keyCurrency),
          completedAtMillis: reader.requireInt(
            PaymentChannel.keyCompletedAtMillis,
          ),
        );
      case PaymentChannel.stateFailed:
        return PaymentProgressDto.failed(
          reader.requireString(PaymentChannel.keyErrorCode),
          paymentId: reader.requireString(PaymentChannel.keyPaymentId),
          attemptId: reader.requireString(PaymentChannel.keyAttemptId),
        );
      default:
        throw const MalformedPayloadException(
          'payment progress has an unknown state',
        );
    }
  }

  /// One of `idle`, `running`, `succeeded`, `failed`, `cancelled`.
  final String state;
  final String? paymentId;
  final String? attemptId;
  final int? percent;
  final String? transactionId;
  final int? amountMinor;
  final String? currency;
  final int? completedAtMillis;
  final String? errorCode;

  Map<String, Object?> toMap() => {
    ChannelContract.keySchemaVersion: ChannelContract.schemaVersion,
    PaymentChannel.keyState: state,
    if (attemptId != null) PaymentChannel.keyAttemptId: attemptId,
    if (paymentId != null) PaymentChannel.keyPaymentId: paymentId,
    if (percent != null) PaymentChannel.keyPercent: percent,
    if (transactionId != null) PaymentChannel.keyTransactionId: transactionId,
    if (amountMinor != null) PaymentChannel.keyAmountMinor: amountMinor,
    if (currency != null) PaymentChannel.keyCurrency: currency,
    if (completedAtMillis != null)
      PaymentChannel.keyCompletedAtMillis: completedAtMillis,
    if (errorCode != null) PaymentChannel.keyErrorCode: errorCode,
  };

  @override
  List<Object?> get props => [
    state,
    paymentId,
    attemptId,
    percent,
    transactionId,
    amountMinor,
    currency,
    completedAtMillis,
    errorCode,
  ];
}
