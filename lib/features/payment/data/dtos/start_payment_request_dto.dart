import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/core/platform/wire_reader.dart';

/// The `startPayment` arguments: flat primitives only. The foreground service
/// needs an id and an amount; its notification text is native resources, so no
/// user-facing text and no merchant data crosses the channel.
final class StartPaymentRequestDto extends Equatable {
  const StartPaymentRequestDto({
    required this.paymentId,
    required this.attemptId,
    required this.amountMinor,
    required this.currency,
  });

  factory StartPaymentRequestDto.fromMap(Object? raw) {
    final reader = WireReader(raw, what: 'start payment request')
      ..requireSchemaVersion();
    return StartPaymentRequestDto(
      paymentId: reader.requireString(PaymentChannel.keyPaymentId),
      attemptId: reader.requireString(PaymentChannel.keyAttemptId),
      amountMinor: reader.requireInt(PaymentChannel.keyAmountMinor),
      currency: reader.requireString(PaymentChannel.keyCurrency),
    );
  }

  final String paymentId;
  final String attemptId;
  final int amountMinor;
  final String currency;

  Map<String, Object?> toMap() => {
    ChannelContract.keySchemaVersion: ChannelContract.schemaVersion,
    PaymentChannel.keyPaymentId: paymentId,
    PaymentChannel.keyAttemptId: attemptId,
    PaymentChannel.keyAmountMinor: amountMinor,
    PaymentChannel.keyCurrency: currency,
  };

  @override
  List<Object?> get props => [paymentId, attemptId, amountMinor, currency];
}
