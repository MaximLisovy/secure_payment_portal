import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/async/replay_latest.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/features/payment/di/payment_providers.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_failures.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_repository.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/security/security.dart';

import '../../../../helpers/fake_async_helpers.dart';
import '../../helpers/payment_fixtures.dart';

const _clean = SecurityStatus(
  root: RootClear(),
  screenRecording: Detection.notDetected,
  windowProtection: WindowProtection.active,
);

final _requestIdProvider = NotifierProvider<_RequestId, String>(_RequestId.new);

class _RequestId extends Notifier<String> {
  @override
  String build() => 'bill-1';
  void select(String id) => state = id;
}

class _Security implements SecurityStatusRepository {
  SecurityStatus status = _clean;
  Completer<Result<SecurityStatus>>? answer;
  int reads = 0;
  @override
  Future<Result<SecurityStatus>> getStatus() async {
    reads++;
    return answer?.future ?? Success(status);
  }

  @override
  Stream<SecurityStatus> watchStatus() => Stream.value(status);
}

class _Payments implements PaymentRepository {
  final progress = ReplayLatest<PaymentProgress>(const PaymentIdle());
  final starts = <String>[];
  final cancels = <String>[];
  Completer<Result<void>>? preparation;
  Completer<Result<void>>? acceptance;
  Result<void> cancellation = Success.unit;
  @override
  Future<Result<void>> preparePayment() async =>
      preparation?.future ?? Success.unit;
  @override
  Future<Result<void>> startPayment(
    PaymentDetails details, {
    required String attemptId,
  }) async {
    starts.add(attemptId);
    return acceptance?.future ?? Success.unit;
  }

  @override
  Future<Result<void>> cancelPayment({required String attemptId}) async {
    cancels.add(attemptId);
    return cancellation;
  }

  @override
  Future<Result<PaymentDetails>> getPaymentDetails(String paymentId) async =>
      Success(sampleDetails);
  @override
  Stream<PaymentProgress> watchProgress() => progress.stream;
}

ProviderContainer _container(_Security security, _Payments payments) {
  var sequence = 0;
  final container = ProviderContainer.test(
    overrides: [
      paymentIdProvider.overrideWith((ref) => ref.watch(_requestIdProvider)),
      securityStatusRepositoryProvider.overrideWithValue(security),
      paymentRepositoryProvider.overrideWithValue(payments),
      paymentAttemptIdFactoryProvider.overrideWithValue(
        () => 'attempt-${++sequence}',
      ),
    ],
  );
  container.listen(paymentFlowProvider, (_, _) {});
  return container;
}

void main() {
  test(
    'a changed request invalidates confirmation before new details arrive',
    () {
      fakeAsync((async) {
        final security = _Security()
          ..answer = Completer<Result<SecurityStatus>>();
        final payments = _Payments();
        final container = _container(security, payments);
        final flow = container.read(paymentFlowProvider.notifier)
          ..begin(sampleDetails);
        async.flushMicrotasks();
        unawaited(flow.confirm());
        async.flushMicrotasks();
        container
            .read(_requestIdProvider.notifier)
            .select('still-loading-order');
        async.flushMicrotasks();
        security.answer?.complete(const Success(_clean));
        async.flushMicrotasks();
        expect(payments.starts, isEmpty);
        async.elapse(Duration.zero);
        expectNoPendingTimers(async);
      });
    },
  );
  test('permission preparation finishes before a fresh security read', () {
    fakeAsync((async) {
      final security = _Security();
      final payments = _Payments()..preparation = Completer<Result<void>>();
      final container = _container(security, payments);
      final flow = container.read(paymentFlowProvider.notifier)
        ..begin(sampleDetails);
      async.flushMicrotasks();
      unawaited(flow.confirm());
      async.flushMicrotasks();
      expect(security.reads, 0);
      security.status = _clean.copyWith(screenRecording: Detection.detected);
      payments.preparation?.complete(Success.unit);
      async.flushMicrotasks();
      expect(payments.starts, isEmpty);
      expect(
        flow.state,
        const PaymentFlowBlocked(SecurityBlockReason.screenRecording),
      );
    });
  });

  for (final stage in ['preparation', 'security']) {
    test(
      'changing the bill during $stage invalidates the old confirmation',
      () {
        fakeAsync((async) {
          final security = _Security();
          final payments = _Payments();
          if (stage == 'preparation') {
            payments.preparation = Completer<Result<void>>();
          }
          if (stage == 'security') {
            security.answer = Completer<Result<SecurityStatus>>();
          }
          final container = _container(security, payments);
          final flow = container.read(paymentFlowProvider.notifier)
            ..begin(sampleDetails);
          async.flushMicrotasks();
          unawaited(flow.confirm());
          async.flushMicrotasks();
          flow.begin(detailsWith([usdItem(900)]));
          async.flushMicrotasks();
          payments.preparation?.complete(Success.unit);
          security.answer?.complete(const Success(_clean));
          async.flushMicrotasks();
          expect(payments.starts, isEmpty);
          expect(flow.state, const PaymentFlowReady());
        });
      },
    );
  }

  test('disposing the flow during preparation never starts a payment', () {
    fakeAsync((async) {
      final security = _Security();
      final payments = _Payments()..preparation = Completer<Result<void>>();
      final container = _container(security, payments);
      final flow = container.read(paymentFlowProvider.notifier)
        ..begin(sampleDetails);
      async.flushMicrotasks();
      unawaited(flow.confirm());
      async.flushMicrotasks();
      container.dispose();
      payments.preparation?.complete(Success.unit);
      async.flushMicrotasks();
      expect(payments.starts, isEmpty);
      expect(security.reads, 0);
    });
  });

  test('unrelated progress cannot hide a rejected start', () {
    fakeAsync((async) {
      final security = _Security();
      final payments = _Payments()..acceptance = Completer<Result<void>>();
      final container = _container(security, payments);
      final flow = container.read(paymentFlowProvider.notifier)
        ..begin(sampleDetails);
      async.flushMicrotasks();
      unawaited(flow.confirm());
      async.flushMicrotasks();
      payments.progress.add(
        const PaymentInProgress('another-bill', 50, attemptId: 'old'),
      );
      async.flushMicrotasks();
      expect(flow.state, const PaymentFlowConfirming());
      payments.acceptance?.complete(const Err(PaymentInProgressFailure()));
      async.flushMicrotasks();
      expect(flow.state, const PaymentFlowFailure(PaymentInProgressFailure()));
    });
  });

  test('a command rejection remains visible after its optimistic progress', () {
    fakeAsync((async) {
      final payments = _Payments()..acceptance = Completer<Result<void>>();
      final container = _container(_Security(), payments);
      final flow = container.read(paymentFlowProvider.notifier)
        ..begin(sampleDetails);
      async.flushMicrotasks();
      unawaited(flow.confirm());
      async.flushMicrotasks();
      payments.progress.add(
        const PaymentInProgress('bill-1', 0, attemptId: 'attempt-1'),
      );
      async.flushMicrotasks();
      payments.acceptance?.complete(const Err(PaymentStartNotAllowedFailure()));
      async.flushMicrotasks();
      expect(
        flow.state,
        const PaymentFlowFailure(PaymentStartNotAllowedFailure()),
      );
    });
  });

  test('late cancellation from the previous attempt cannot end a retry', () {
    fakeAsync((async) {
      final payments = _Payments();
      final container = _container(_Security(), payments);
      final flow = container.read(paymentFlowProvider.notifier)
        ..begin(sampleDetails);
      async.flushMicrotasks();
      unawaited(flow.confirm());
      async.flushMicrotasks();
      payments.progress.add(
        const PaymentCancelled(paymentId: 'bill-1', attemptId: 'attempt-1'),
      );
      async.flushMicrotasks();
      unawaited(flow.retry());
      async.flushMicrotasks();
      unawaited(flow.confirm());
      async.flushMicrotasks();
      payments.progress.add(
        const PaymentCancelled(paymentId: 'bill-1', attemptId: 'attempt-1'),
      );
      async.flushMicrotasks();
      expect(flow.state, const PaymentFlowProcessing(percent: 0));
      payments.cancellation = const Err(PlatformFailure('UNAVAILABLE'));
      unawaited(flow.cancel());
      async.flushMicrotasks();
      expect(payments.cancels, ['attempt-2']);
      expect(
        (flow.state as PaymentFlowProcessing).cancellationFailure,
        const PlatformFailure('UNAVAILABLE'),
      );
    });
  });
}
