import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/domain/bill_backend_control.dart';

import '../../../../helpers/fake_bills.dart';

void main() {
  group('FakePaymentRemoteDataSource', () {
    test('returns the bill with that id', () async {
      final source = FakePaymentRemoteDataSource(bills: FakeBills.all);

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
        FakePaymentRemoteDataSource(
          bills: FakeBills.all,
        ).fetchPaymentDetails('nope'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('can play a failing network, and recover', () async {
      final source = FakePaymentRemoteDataSource(
        bills: FakeBills.all,
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

    test('takes exactly the configured latency', () {
      fakeAsync((async) {
        final source = FakePaymentRemoteDataSource(
          bills: FakeBills.all,
          latency: const Duration(seconds: 2),
        );
        var done = false;
        unawaited(
          source
              .fetchPaymentDetails(FakeBills.retailOrderId)
              .then((_) => done = true),
        );

        async.elapse(const Duration(seconds: 1));
        expect(done, isFalse);

        async.elapse(const Duration(seconds: 1));
        expect(done, isTrue);
      });
    });

    test('the demo bills are keyed by their own ids', () {
      for (final entry in FakeBills.all.entries) {
        expect(entry.value.id, entry.key);
      }
    });
  });

  group('as a BillBackendControl', () {
    test('goes offline and comes back', () async {
      final source = FakePaymentRemoteDataSource(bills: FakeBills.all);
      final BillBackendControl control = source;
      expect(control.online, isTrue);

      control.setOnline(online: false);
      expect(control.online, isFalse);
      await expectLater(
        source.fetchPaymentDetails(FakeBills.retailOrderId),
        throwsA(isA<NetworkException>()),
      );

      control.setOnline(online: true);
      expect(control.online, isTrue);
      expect(
        await source.fetchPaymentDetails(FakeBills.retailOrderId),
        FakeBills.retailOrder,
      );
    });
  });
}
