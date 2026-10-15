import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/core/platform/wire_reader.dart';

/// One bill line as the (fake) backend returns it.
final class BillLineItemDto extends Equatable {
  const BillLineItemDto({
    required this.label,
    required this.amountMinor,
    required this.kind,
  });

  factory BillLineItemDto.fromMap(Object? raw) {
    final reader = WireReader(raw, what: 'bill line item');
    return BillLineItemDto(
      label: reader.requireString(keyLabel),
      amountMinor: reader.requireInt(keyAmountMinor),
      kind: reader.requireString(keyKind),
    );
  }

  static const String keyLabel = 'label';
  static const String keyAmountMinor = 'amountMinor';
  static const String keyKind = 'kind';

  final String label;
  final int amountMinor;

  /// `charge`, `tax`, `fee` or `discount`.
  final String kind;

  @override
  List<Object?> get props => [label, amountMinor, kind];
}

/// A bill as the (fake) backend returns it: JSON-shaped, not a channel
/// payload, so it carries no `schemaVersion`.
final class PaymentDetailsDto extends Equatable {
  const PaymentDetailsDto({
    required this.id,
    required this.merchantName,
    required this.reference,
    required this.currency,
    required this.lineItems,
  });

  factory PaymentDetailsDto.fromMap(Object? raw) {
    final reader = WireReader(raw, what: 'payment details');
    return PaymentDetailsDto(
      id: reader.requireString(keyId),
      merchantName: reader.requireString(keyMerchantName),
      reference: reader.requireString(keyReference),
      currency: reader.requireString(keyCurrency),
      lineItems: [
        for (final item in reader.requireList(keyLineItems))
          BillLineItemDto.fromMap(item),
      ],
    );
  }

  static const String keyId = 'id';
  static const String keyMerchantName = 'merchantName';
  static const String keyReference = 'reference';
  static const String keyCurrency = 'currency';
  static const String keyLineItems = 'lineItems';

  final String id;
  final String merchantName;
  final String reference;

  /// An ISO 4217 code; every line is in it.
  final String currency;
  final List<BillLineItemDto> lineItems;

  @override
  List<Object?> get props => [id, merchantName, reference, currency, lineItems];
}
