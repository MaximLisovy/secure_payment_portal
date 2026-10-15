import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_bills.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';

void main() {
  group('FakePaymentRemoteDataSource', () {
    test('returns the bill with that id', () async {
      final source = FakePaymentRemoteDataSource();

      expect(
        await source.fetchPaymentDetails(FakeBills.retailOrderId),
        FakeBills.retailOrder,
      );
      expect(
        await source.fetchPaymentDetails(FakeBills.utilityBillId),
        FakeBills.utilityBill,
      );
    });

    test('an unknown id is not found', () async {
      await expectLater(
        FakePaymentRemoteDataSource().fetchPaymentDetails('nope'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('can play a failing network, and recover', () async {
      final source = FakePaymentRemoteDataSource(
        outcome: FakeRemoteOutcome.networkError,
      );

      await expectLater(
        source.fetchPaymentDetails(FakeBills.retailOrderId),
        throwsA(isA<NetworkException>()),
      );

      source.outcome = FakeRemoteOutcome.success;
      expect(
        await source.fetchPaymentDetails(FakeBills.retailOrderId),
        FakeBills.retailOrder,
      );
    });

    test('serves a custom catalog', () async {
      final source = FakePaymentRemoteDataSource(
        bills: {'only': FakeBills.utilityBill},
      );

      expect(await source.fetchPaymentDetails('only'), FakeBills.utilityBill);
      await expectLater(
        source.fetchPaymentDetails(FakeBills.retailOrderId),
        throwsA(isA<NotFoundException>()),
      );
    });

    testWidgets('takes exactly the configured latency', (tester) async {
      final source = FakePaymentRemoteDataSource(
        latency: const Duration(seconds: 2),
      );
      var done = false;
      unawaited(
        source
            .fetchPaymentDetails(FakeBills.retailOrderId)
            .then((_) => done = true),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(done, isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(done, isTrue);
    });

    test('the demo bills are keyed by their own ids', () {
      for (final entry in FakeBills.all.entries) {
        expect(entry.value.id, entry.key);
      }
    });
  });
}
