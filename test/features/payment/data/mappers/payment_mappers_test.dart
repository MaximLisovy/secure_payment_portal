import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_bills.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_details_dto.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_progress_dto.dart';
import 'package:secure_payment_portal/features/payment/data/mappers/payment_details_mapper.dart';
import 'package:secure_payment_portal/features/payment/data/mappers/payment_progress_mapper.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_failures.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';

import '../../helpers/payment_fixtures.dart';

Matcher get _malformed => throwsA(isA<MalformedPayloadException>());

PaymentDetailsDto _bill({
  String currency = 'USD',
  List<BillLineItemDto> items = const [
    BillLineItemDto(label: 'Item', amountMinor: 1000, kind: 'charge'),
  ],
}) => PaymentDetailsDto(
  id: 'bill-1',
  merchantName: 'Shop',
  reference: 'Order #1',
  currency: currency,
  lineItems: items,
);

void main() {
  group('PaymentDetailsMapper.toEntity', () {
    test('maps a bill, giving every line the bill currency', () {
      final details = PaymentDetailsMapper.toEntity(
        _bill(
          items: const [
            BillLineItemDto(label: 'Item', amountMinor: 1000, kind: 'charge'),
            BillLineItemDto(label: 'Tax', amountMinor: 100, kind: 'tax'),
          ],
        ),
      );

      expect(
        details,
        PaymentDetails(
          id: 'bill-1',
          merchantName: 'Shop',
          reference: 'Order #1',
          currency: Currency.usd,
          lineItems: [
            const BillLineItem(
              label: 'Item',
              amount: Money.minor(1000, Currency.usd),
              kind: LineItemKind.charge,
            ),
            const BillLineItem(
              label: 'Tax',
              amount: Money.minor(100, Currency.usd),
              kind: LineItemKind.tax,
            ),
          ],
        ),
      );
      expect(details.total, const Money.minor(1100, Currency.usd));
      expect(details.lineItems.map((i) => i.kind), [
        LineItemKind.charge,
        LineItemKind.tax,
      ]);
    });

    test('keeps a negative amount as a discount', () {
      final details = PaymentDetailsMapper.toEntity(
        _bill(
          items: const [
            BillLineItemDto(label: 'Item', amountMinor: 1000, kind: 'charge'),
            BillLineItemDto(
              label: 'Promo',
              amountMinor: -200,
              kind: 'discount',
            ),
          ],
        ),
      );

      expect(details.total, const Money.minor(800, Currency.usd));
    });

    test('rejects an unknown currency and an unknown line kind', () {
      expect(
        () => PaymentDetailsMapper.toEntity(_bill(currency: 'XXX')),
        _malformed,
      );
      expect(
        () => PaymentDetailsMapper.toEntity(
          _bill(
            items: const [
              BillLineItemDto(label: 'x', amountMinor: 1, kind: 'gift'),
            ],
          ),
        ),
        _malformed,
      );
    });

    test('maps the demo bills to the totals they promise', () {
      final retail = PaymentDetailsMapper.toEntity(FakeBills.retailOrder);
      final utility = PaymentDetailsMapper.toEntity(FakeBills.utilityBill);

      expect(retail.total, const Money.minor(10939, Currency.usd));
      expect(retail.total.toDecimalString(), '109.39');
      expect(utility.total, const Money.minor(8961, Currency.eur));
      expect(utility.total.toDecimalString(), '89.61');
      expect(retail.isPayable, isTrue);
      expect(utility.isPayable, isTrue);
    });
  });

  group('PaymentDetailsMapper.toStartRequest', () {
    test('sends the id, the total in minor units and the currency code', () {
      expect(
        PaymentDetailsMapper.toStartRequest(
          sampleDetails,
          attemptId: 'attempt-1',
        ),
        sampleRequest,
      );
    });
  });

  group('PaymentProgressMapper.toEntity', () {
    test('maps idle and cancelled', () {
      expect(
        PaymentProgressMapper.toEntity(PaymentProgressDto.idle),
        const PaymentIdle(),
      );
      expect(
        PaymentProgressMapper.toEntity(
          const PaymentProgressDto.cancelled(
            paymentId: 'bill-1',
            attemptId: 'attempt-1',
          ),
        ),
        const PaymentCancelled(paymentId: 'bill-1', attemptId: 'attempt-1'),
      );
    });

    test('maps running to its payment and percent', () {
      expect(
        PaymentProgressMapper.toEntity(
          const PaymentProgressDto.running(
            'bill-1',
            40,
            attemptId: 'attempt-1',
          ),
        ),
        const PaymentInProgress('bill-1', 40, attemptId: 'attempt-1'),
      );
    });

    test('accepts the 0 and 100 percent edges', () {
      expect(
        PaymentProgressMapper.toEntity(
          const PaymentProgressDto.running('a', 0, attemptId: 'attempt-1'),
        ),
        const PaymentInProgress('a', 0, attemptId: 'attempt-1'),
      );
      expect(
        PaymentProgressMapper.toEntity(
          const PaymentProgressDto.running('a', 100, attemptId: 'attempt-1'),
        ),
        const PaymentInProgress('a', 100, attemptId: 'attempt-1'),
      );
    });

    test('rejects a percent outside 0..100', () {
      expect(
        () => PaymentProgressMapper.toEntity(
          const PaymentProgressDto.running('a', -1, attemptId: 'attempt-1'),
        ),
        _malformed,
      );
      expect(
        () => PaymentProgressMapper.toEntity(
          const PaymentProgressDto.running('a', 101, attemptId: 'attempt-1'),
        ),
        _malformed,
      );
    });

    test('maps succeeded to a receipt with a UTC completion time', () {
      final progress = PaymentProgressMapper.toEntity(
        const PaymentProgressDto.succeeded(
          paymentId: 'bill-1',
          transactionId: 'tx-1',
          amountMinor: 1100,
          currency: 'USD',
          completedAtMillis: 1760529600000,
          attemptId: 'attempt-1',
        ),
      );

      expect(progress, isA<PaymentSucceeded>());
      final result = (progress as PaymentSucceeded).result;
      expect(result.paymentId, 'bill-1');
      expect(result.transactionId, 'tx-1');
      expect(result.amount, const Money.minor(1100, Currency.usd));
      expect(
        result.completedAt,
        DateTime.fromMillisecondsSinceEpoch(1760529600000, isUtc: true),
      );
      expect(result.completedAt.isUtc, isTrue);
    });

    test('rejects a receipt in an unknown currency', () {
      expect(
        () => PaymentProgressMapper.toEntity(
          const PaymentProgressDto.succeeded(
            paymentId: 'a',
            transactionId: 't',
            amountMinor: 1,
            currency: 'XXX',
            completedAtMillis: 1,
            attemptId: 'attempt-1',
          ),
        ),
        _malformed,
      );
    });

    test(
      'maps failure codes to typed failures, and never drops an unknown one',
      () {
        expect(
          PaymentProgressMapper.toEntity(
            const PaymentProgressDto.failed(
              PaymentChannel.failureDeclined,
              paymentId: 'bill-1',
              attemptId: 'attempt-1',
            ),
          ),
          const PaymentFailed(
            PaymentDeclinedFailure(),
            paymentId: 'bill-1',
            attemptId: 'attempt-1',
          ),
        );
        expect(
          PaymentProgressMapper.toEntity(
            const PaymentProgressDto.failed(
              PaymentChannel.failureProcessing,
              paymentId: 'bill-1',
              attemptId: 'attempt-1',
            ),
          ),
          const PaymentFailed(
            PaymentProcessingFailure(),
            paymentId: 'bill-1',
            attemptId: 'attempt-1',
          ),
        );
        expect(
          PaymentProgressMapper.toEntity(
            const PaymentProgressDto.failed(
              'something_new',
              paymentId: 'bill-1',
              attemptId: 'attempt-1',
            ),
          ),
          const PaymentFailed(
            PaymentProcessingFailure(),
            paymentId: 'bill-1',
            attemptId: 'attempt-1',
          ),
        );
      },
    );

    test('rejects a state whose fields are missing or that is unknown', () {
      expect(
        () => PaymentProgressMapper.toEntity(
          const PaymentProgressDto(state: PaymentChannel.stateRunning),
        ),
        _malformed,
      );
      expect(
        () => PaymentProgressMapper.toEntity(
          const PaymentProgressDto(state: PaymentChannel.stateSucceeded),
        ),
        _malformed,
      );
      expect(
        () => PaymentProgressMapper.toEntity(
          const PaymentProgressDto(state: PaymentChannel.stateFailed),
        ),
        _malformed,
      );
      expect(
        () => PaymentProgressMapper.toEntity(
          const PaymentProgressDto(state: 'exploded'),
        ),
        _malformed,
      );
    });
  });
}
