import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_providers.dart';
import 'package:secure_payment_portal/app/di/root_overrides.dart';
import 'package:secure_payment_portal/app/payment/payment_request_providers.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/error/failure_exception.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_bills.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_details_dto.dart';
import 'package:secure_payment_portal/features/payment/di/payment_data_source_providers.dart';
import 'package:secure_payment_portal/features/payment/di/payment_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';

import '../../helpers/flow_harness.dart';
import '../../helpers/payment_fixtures.dart';

class _CountingRemote implements PaymentRemoteDataSource {
  final calls = <String>[];

  @override
  Future<PaymentDetailsDto> fetchPaymentDetails(String paymentId) async {
    calls.add(paymentId);
    return FakePaymentRemoteDataSource().fetchPaymentDetails(paymentId);
  }
}

ProviderContainer _container(
  FakePaymentRemoteDataSource remote, {
  String paymentId = 'bill-1',
}) {
  final container = ProviderContainer.test(
    overrides: [
      paymentIdProvider.overrideWithValue(paymentId),
      paymentRemoteDataSourceProvider.overrideWithValue(remote),
    ],
  );
  // The provider is auto-dispose: keep it alive for the test.
  container.listen(paymentDetailsProvider, (_, _) {});
  return container;
}

Failure _failureOf(AsyncValue<Object?> value) =>
    failureOfError(value.error ?? fail('expected an error'));

void main() {
  group('PaymentDetailsNotifier', () {
    test(
      'changing the request reloads; changing layout preserves an explicit request',
      () {
        fakeAsync((async) {
          final remote = _CountingRemote();
          final container = ProviderContainer.test(
            overrides: [
              ...rootOverrides(initialBrand: retailBrand),
              paymentRemoteDataSourceProvider.overrideWithValue(remote),
            ],
          );
          container.listen(paymentDetailsProvider, (_, _) {});
          async.flushMicrotasks();
          final selection = container.read(selectedPaymentIdProvider.notifier);
          selection.select(FakeBills.utilityBillId);
          async.elapse(Duration.zero);
          expect(
            container.read(paymentDetailsProvider).value?.id,
            FakeBills.utilityBillId,
          );
          expect(remote.calls, [
            FakeBills.retailOrderId,
            FakeBills.utilityBillId,
          ]);

          container.read(activeBrandProvider.notifier).select('utility');
          async.elapse(Duration.zero);
          expect(
            container.read(paymentDetailsProvider).value?.id,
            FakeBills.utilityBillId,
          );
          expect(remote.calls, [
            FakeBills.retailOrderId,
            FakeBills.utilityBillId,
          ]);
        });
      },
    );
    test('loads the bill supplied by the host', () {
      fakeAsync((async) {
        final container = _container(
          FakePaymentRemoteDataSource(bills: {'bill-1': harnessBillDto}),
        );
        expect(
          container.read(paymentDetailsProvider),
          isA<AsyncLoading<Object?>>(),
        );

        async.flushMicrotasks();

        final loaded = container.read(paymentDetailsProvider);
        expect(loaded.value, sampleDetails);
        expect(container.read(loadedPaymentDetailsProvider), sampleDetails);
      });
    });

    final failures = <(String, FakePaymentRemoteDataSource, String, Failure)>[
      (
        'an unknown bill',
        FakePaymentRemoteDataSource(bills: const {}),
        'bill-1',
        const NotFoundFailure(),
      ),
      (
        'a network error',
        FakePaymentRemoteDataSource(
          bills: {'bill-1': harnessBillDto},
          outcome: FakeRemoteOutcome.networkError,
        ),
        'bill-1',
        const NetworkFailure(),
      ),
      (
        'a bill in a currency nobody knows',
        FakePaymentRemoteDataSource(
          bills: {
            'bill-1': const PaymentDetailsDto(
              id: 'bill-1',
              merchantName: 'm',
              reference: 'r',
              currency: 'XXX',
              lineItems: [],
            ),
          },
        ),
        'bill-1',
        const InvalidDataFailure(),
      ),
    ];
    for (final (name, remote, id, expected) in failures) {
      test('holds $name as an error carrying the typed failure', () {
        fakeAsync((async) {
          final container = _container(remote, paymentId: id);

          async.flushMicrotasks();

          final state = container.read(paymentDetailsProvider);
          expect(state.hasError, isTrue);
          expect(_failureOf(state), expected);
        });
      });
    }

    test('loads again after a failure when the data is invalidated', () {
      fakeAsync((async) {
        final remote = FakePaymentRemoteDataSource(
          bills: {'bill-1': harnessBillDto},
          outcome: FakeRemoteOutcome.networkError,
        );
        final container = _container(remote);
        async.flushMicrotasks();
        expect(container.read(paymentDetailsProvider).hasError, isTrue);

        remote.outcome = FakeRemoteOutcome.success;
        container.invalidate(paymentDetailsProvider);
        // Riverpod rebuilds an invalidated provider on the next event-loop turn.
        async.elapse(Duration.zero);

        expect(container.read(paymentDetailsProvider).value, sampleDetails);
      });
    });

    test(
      'reading the loaded bill before it has loaded is a bug and throws',
      () {
        fakeAsync((async) {
          final container = _container(
            FakePaymentRemoteDataSource(bills: {'bill-1': harnessBillDto}),
          );

          expect(
            () => container.read(loadedPaymentDetailsProvider),
            throwsA(anything),
          );
          async.flushMicrotasks();
        });
      },
    );

    test(
      'an unexpected error reads as an unexpected failure, never a crash',
      () {
        expect(failureOfError(StateError('bug')), const UnexpectedFailure());
        expect(
          failureOfError(const FailureException(NetworkFailure())),
          const NetworkFailure(),
        );
      },
    );
  });
}
