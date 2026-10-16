import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_details_dto.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/start_payment_request_dto.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';

/// Bill DTO ↔ entity. Anything unusable throws a [MalformedPayloadException],
/// which the repository turns into an `InvalidDataFailure`.
abstract final class PaymentDetailsMapper {
  static PaymentDetails toEntity(PaymentDetailsDto dto) {
    final currency = Currency.fromCode(dto.currency);
    if (currency == null) {
      throw const MalformedPayloadException(
        'payment details: unknown currency',
      );
    }
    return PaymentDetails(
      id: dto.id,
      merchantName: dto.merchantName,
      reference: dto.reference,
      currency: currency,
      lineItems: [
        for (final item in dto.lineItems)
          BillLineItem(
            label: item.label,
            amount: Money.minor(item.amountMinor, currency),
            kind: _kindFromWire(item.kind),
          ),
      ],
    );
  }

  /// Host-supplied demo configuration becomes a backend DTO at the boundary.
  static PaymentDetailsDto toDto(PaymentDetails details) => PaymentDetailsDto(
    id: details.id,
    merchantName: details.merchantName,
    reference: details.reference,
    currency: details.currency.code,
    lineItems: [
      for (final item in details.lineItems)
        BillLineItemDto(
          label: item.label,
          amountMinor: item.amount.minorUnits,
          kind: item.kind.name,
        ),
    ],
  );

  /// The request the platform needs to process [details].
  static StartPaymentRequestDto toStartRequest(
    PaymentDetails details, {
    required String attemptId,
  }) {
    final total = details.total;
    return StartPaymentRequestDto(
      paymentId: details.id,
      attemptId: attemptId,
      amountMinor: total.minorUnits,
      currency: total.currency.code,
    );
  }

  static LineItemKind _kindFromWire(String wire) {
    for (final kind in LineItemKind.values) {
      if (kind.name == wire) return kind;
    }
    throw const MalformedPayloadException('payment details: unknown line kind');
  }
}
