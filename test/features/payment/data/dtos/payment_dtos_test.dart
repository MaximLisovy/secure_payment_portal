import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_details_dto.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_progress_dto.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/start_payment_request_dto.dart';

import '../../helpers/payment_fixtures.dart';

Matcher get _malformed => throwsA(isA<MalformedPayloadException>());

Map<Object?, Object?> _event(
  String state, [
  Map<Object?, Object?> extra = const {},
]) => <Object?, Object?>{
  ChannelContract.keySchemaVersion: ChannelContract.schemaVersion,
  PaymentChannel.keyState: state,
  ...extra,
};

Map<Object?, Object?> _billMap({Object? lineItems}) => <Object?, Object?>{
  PaymentDetailsDto.keyId: 'bill-1',
  PaymentDetailsDto.keyMerchantName: 'Shop',
  PaymentDetailsDto.keyReference: 'Order #1',
  PaymentDetailsDto.keyCurrency: 'USD',
  PaymentDetailsDto.keyLineItems:
      lineItems ??
      <Object?>[
        <Object?, Object?>{
          BillLineItemDto.keyLabel: 'Item',
          BillLineItemDto.keyAmountMinor: 1000,
          BillLineItemDto.keyKind: 'charge',
        },
      ],
};

void main() {
  group('PaymentDetailsDto.fromMap', () {
    test('reads a bill with its line items', () {
      final dto = PaymentDetailsDto.fromMap(_billMap());

      expect(dto.id, 'bill-1');
      expect(dto.currency, 'USD');
      expect(dto.lineItems, const [
        BillLineItemDto(label: 'Item', amountMinor: 1000, kind: 'charge'),
      ]);
    });

    test(
      'needs no schemaVersion: it is JSON-shaped, not a channel payload',
      () {
        expect(() => PaymentDetailsDto.fromMap(_billMap()), returnsNormally);
      },
    );

    test('rejects anything that is not the documented shape', () {
      expect(() => PaymentDetailsDto.fromMap(null), _malformed);
      expect(
        () => PaymentDetailsDto.fromMap(_billMap(lineItems: 'x')),
        _malformed,
      );
      expect(
        () => PaymentDetailsDto.fromMap(_billMap(lineItems: <Object?>['x'])),
        _malformed,
      );
      expect(
        () => PaymentDetailsDto.fromMap(
          _billMap(
            lineItems: <Object?>[
              <Object?, Object?>{BillLineItemDto.keyLabel: 'Item'},
            ],
          ),
        ),
        _malformed,
      );
      expect(
        () => PaymentDetailsDto.fromMap(<Object?, Object?>{
          ..._billMap(),
          PaymentDetailsDto.keyCurrency: 840,
        }),
        _malformed,
      );
    });
  });

  group('StartPaymentRequestDto', () {
    test('round-trips through the wire map', () {
      expect(
        StartPaymentRequestDto.fromMap(sampleRequest.toMap()),
        sampleRequest,
      );
    });

    test('writes only flat primitives and the schema version', () {
      final map = sampleRequest.toMap();

      expect(
        map.keys,
        unorderedEquals([
          ChannelContract.keySchemaVersion,
          PaymentChannel.keyPaymentId,
          PaymentChannel.keyAttemptId,
          PaymentChannel.keyAmountMinor,
          PaymentChannel.keyCurrency,
        ]),
      );
      expect(map.values.every((v) => v is String || v is int), isTrue);
    });

    test('rejects a malformed request', () {
      expect(() => StartPaymentRequestDto.fromMap(null), _malformed);
      expect(
        () => StartPaymentRequestDto.fromMap(<Object?, Object?>{
          ChannelContract.keySchemaVersion: ChannelContract.schemaVersion,
          PaymentChannel.keyPaymentId: 'x',
          PaymentChannel.keyAmountMinor: '1100',
          PaymentChannel.keyCurrency: 'USD',
        }),
        _malformed,
      );
    });
  });

  group('PaymentProgressDto.fromMap', () {
    final valid = <String, PaymentProgressDto>{
      'idle': PaymentProgressDto.idle,
      'cancelled': const PaymentProgressDto.cancelled(
        paymentId: 'bill-1',
        attemptId: 'attempt-1',
      ),
      'running': const PaymentProgressDto.running(
        'bill-1',
        40,
        attemptId: 'attempt-1',
      ),
      'succeeded': const PaymentProgressDto.succeeded(
        paymentId: 'bill-1',
        transactionId: 'tx-1',
        amountMinor: 1100,
        currency: 'USD',
        completedAtMillis: 1760000000000,
        attemptId: 'attempt-1',
      ),
      'failed': const PaymentProgressDto.failed(
        PaymentChannel.failureDeclined,
        paymentId: 'bill-1',
        attemptId: 'attempt-1',
      ),
    };
    for (final entry in valid.entries) {
      test('round-trips a ${entry.key} event', () {
        expect(PaymentProgressDto.fromMap(entry.value.toMap()), entry.value);
      });
    }

    test('toMap leaves out what a state does not carry', () {
      expect(
        PaymentProgressDto.idle.toMap().keys,
        unorderedEquals([
          ChannelContract.keySchemaVersion,
          PaymentChannel.keyState,
        ]),
      );
    });

    test('rejects an event that is missing what its state needs', () {
      expect(
        () => PaymentProgressDto.fromMap(
          _event(PaymentChannel.stateRunning, {
            PaymentChannel.keyPaymentId: 'x',
            PaymentChannel.keyAttemptId: 'attempt-1',
          }),
        ),
        _malformed,
      );
      expect(
        () => PaymentProgressDto.fromMap(
          _event(PaymentChannel.stateRunning, {PaymentChannel.keyPercent: 5}),
        ),
        _malformed,
      );
      expect(
        () => PaymentProgressDto.fromMap(_event(PaymentChannel.stateFailed)),
        _malformed,
      );
      for (final missing in [
        PaymentChannel.keyPaymentId,
        PaymentChannel.keyTransactionId,
        PaymentChannel.keyAmountMinor,
        PaymentChannel.keyCurrency,
        PaymentChannel.keyCompletedAtMillis,
      ]) {
        final map = <Object?, Object?>{
          ...const PaymentProgressDto.succeeded(
            paymentId: 'x',
            transactionId: 't',
            amountMinor: 1,
            currency: 'USD',
            completedAtMillis: 1,
            attemptId: 'attempt-1',
          ).toMap(),
        }..remove(missing);

        expect(
          () => PaymentProgressDto.fromMap(map),
          _malformed,
          reason: missing,
        );
      }
    });

    test(
      'rejects an unknown state, a wrong type and a wrong schema version',
      () {
        expect(
          () => PaymentProgressDto.fromMap(_event('exploded')),
          _malformed,
        );
        expect(
          () => PaymentProgressDto.fromMap(
            _event(PaymentChannel.stateRunning, {
              PaymentChannel.keyPaymentId: 'x',
              PaymentChannel.keyAttemptId: 'attempt-1',
              PaymentChannel.keyPercent: '5',
            }),
          ),
          _malformed,
        );
        expect(
          () => PaymentProgressDto.fromMap(<Object?, Object?>{
            ChannelContract.keySchemaVersion: 7,
            PaymentChannel.keyState: PaymentChannel.stateIdle,
          }),
          _malformed,
        );
        expect(() => PaymentProgressDto.fromMap('idle'), _malformed);
      },
    );

    test('does not validate values: that is the mapper\'s job', () {
      // 150 percent is structurally an int.
      expect(
        PaymentProgressDto.fromMap(
          _event(PaymentChannel.stateRunning, {
            PaymentChannel.keyPaymentId: 'x',
            PaymentChannel.keyAttemptId: 'attempt-1',
            PaymentChannel.keyPercent: 150,
          }),
        ).percent,
        150,
      );
    });
  });
}
