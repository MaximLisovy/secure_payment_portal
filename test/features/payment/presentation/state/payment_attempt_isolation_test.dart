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
import 'package:secure_payment_portal/features/payment/domain/payment_result.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_reconciliation.dart';
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
  int watches = 0;
  Stream<SecurityStatus>? events;
  @override
  Future<Result<SecurityStatus>> getStatus() async {
    reads++;
    return answer?.future ?? Success(status);
  }

  @override
  Stream<SecurityStatus> watchStatus() {
    watches++;
    return events ?? Stream.value(status);
  }
}

class _Payments implements PaymentRepository {
  final progress = ReplayLatest<PaymentProgress>(const PaymentIdle());
  final starts = <String>[];
  final cancels = <String>[];
  Completer<Result<void>>? preparation;
  Completer<Result<void>>? acceptance;
  Result<void> cancellation = Success.unit;
  Result<void>? startAnswer;
  Result<PaymentProgress> snapshot = const Success(PaymentIdle());
  Completer<Result<PaymentProgress>>? snapshotAnswer;
  final snapshots = <String>[];
  @override
  Future<Result<void>> preparePayment() async =>
      preparation?.future ?? Success.unit;
  @override
  Future<Result<void>> startPayment(
    PaymentDetails details, {
    required String attemptId,
  }) async {
    starts.add(attemptId);
    return acceptance?.future ?? startAnswer ?? Success.unit;
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
  @override
  Future<Result<PaymentProgress>> getPaymentSnapshot({
    required String attemptId,
  }) async {
    snapshots.add(attemptId);
    return snapshotAnswer?.future ?? snapshot;
  }
}

class _DelayedRetryWindow extends SecureWindowNotifier {
  final retryAnswer = Completer<void>();
  @override
  SecureWindowState build() => const SecureWindowProtected();
  @override
  Future<void> retry() => retryAnswer.future;
}

ProviderContainer _container(
  _Security security,
  _Payments payments, {
  SecureWindowNotifier? window,
}) {
  var sequence = 0;
  final container = ProviderContainer.test(
    overrides: [
      paymentIdProvider.overrideWith((ref) => ref.watch(_requestIdProvider)),
      securityStatusRepositoryProvider.overrideWithValue(security),
      if (window != null) secureWindowProvider.overrideWith(() => window),
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
    'restart cannot overwrite a new attempt after its secure-window await',
    () {
      fakeAsync((async) {
        final window = _DelayedRetryWindow();
        final payments = _Payments()
          ..startAnswer = const Err(PaymentStartNotAllowedFailure());
        final container = _container(_Security(), payments, window: window);
        final flow = container.read(paymentFlowProvider.notifier)
          ..begin(sampleDetails);
        async.flushMicrotasks();
        unawaited(flow.confirm());
        async.flushMicrotasks();
        expect(flow.state, isA<PaymentFlowFailure>());
        unawaited(flow.retry());
        async.flushMicrotasks();
        flow.begin(detailsWith([usdItem(900)]));
        async.flushMicrotasks();
        flow.begin(sampleDetails);
        async.flushMicrotasks();
        payments.startAnswer = Success.unit;
        unawaited(flow.confirm());
        async.flushMicrotasks();
        expect(flow.state, const PaymentFlowProcessing(percent: 0));
        window.retryAnswer.complete();
        async.flushMicrotasks();
        expect(flow.state, const PaymentFlowProcessing(percent: 0));
        container.dispose();
        async.flushMicrotasks();
        expectNoPendingTimers(async);
      });
    },
  );

  test('security subscription errors fail closed instead of escaping', () {
    fakeAsync((async) {
      final security = _Security()
        ..events = Stream<SecurityStatus>.error(StateError('status mapping'));
      final container = _container(security, _Payments());
      final flow = container.read(paymentFlowProvider.notifier)
        ..begin(sampleDetails);
      async.flushMicrotasks();
      expect(flow.state, isA<PaymentFlowBlocked>());
      container.dispose();
      async.flushMicrotasks();
      expectNoPendingTimers(async);
    });
  });

  for (final evidence in [
    'start timeout / missing plugin',
    'unscoped failure',
    'stream error',
  ]) {
    test(
      '$evidence keeps the attempt and reconciles immediately with backoff',
      () {
        fakeAsync((async) {
          final payments = _Payments();
          if (evidence == 'start timeout / missing plugin') {
            payments.startAnswer = const Err(PaymentOutcomeUnknownFailure());
          }
          final container = _container(_Security(), payments);
          final flow = container.read(paymentFlowProvider.notifier)
            ..begin(sampleDetails);
          async.flushMicrotasks();
          unawaited(flow.confirm());
          async.flushMicrotasks();
          if (evidence == 'unscoped failure') {
            payments.progress.add(const PaymentFailed(InvalidDataFailure()));
          }
          if (evidence == 'stream error') {
            payments.progress.addError(StateError('wire failed'));
          }
          async.flushMicrotasks();
          expect(flow.state, const PaymentFlowCheckingStatus());
          expect(payments.snapshots, ['attempt-1']);
          unawaited(flow.retry());
          unawaited(flow.confirm());
          async.flushMicrotasks();
          expect(payments.starts, ['attempt-1']);
          async.elapse(const Duration(milliseconds: 249));
          expect(payments.snapshots, hasLength(1));
          async.elapse(const Duration(milliseconds: 1));
          expect(payments.snapshots, hasLength(2));
          async.elapse(const Duration(milliseconds: 500));
          expect(payments.snapshots, hasLength(3));
          payments.progress.add(
            const PaymentInProgress('bill-1', 50, attemptId: 'attempt-1'),
          );
          async.flushMicrotasks();
          expect(flow.state, const PaymentFlowCheckingStatus());
          payments.cancellation = const Err(PlatformFailure('UNAVAILABLE'));
          unawaited(flow.cancel());
          async.flushMicrotasks();
          expect(payments.cancels, ['attempt-1']);
          expect(
            (flow.state as PaymentFlowCheckingStatus).cancelRequested,
            isFalse,
          );
          async.elapse(paymentReconciliationWindow);
          expect((flow.state as PaymentFlowCheckingStatus).expired, isTrue);
          final reads = payments.snapshots.length;
          unawaited(flow.retry());
          async.elapse(paymentReconciliationWindow);
          expect(payments.snapshots, hasLength(reads));
          expect(payments.starts, hasLength(1));
          payments.progress.add(
            const PaymentCancelled(paymentId: 'bill-1', attemptId: 'attempt-1'),
          );
          async.flushMicrotasks();
          expect(flow.state, const PaymentFlowCancelled());
          container.dispose();
          async.flushMicrotasks();
          expectNoPendingTimers(async);
        });
      },
    );
  }

  for (final terminal in <PaymentProgress>[
    PaymentSucceeded(
      PaymentResult(
        paymentId: 'bill-1',
        attemptId: 'attempt-1',
        transactionId: 'tx',
        amount: sampleDetails.total,
        completedAt: DateTime.utc(2026),
      ),
    ),
    const PaymentFailed(
      PaymentDeclinedFailure(),
      paymentId: 'bill-1',
      attemptId: 'attempt-1',
    ),
    const PaymentCancelled(paymentId: 'bill-1', attemptId: 'attempt-1'),
  ]) {
    test('snapshot resolves ${terminal.runtimeType} after transport loss', () {
      fakeAsync((async) {
        final payments = _Payments()
          ..startAnswer = const Err(PaymentOutcomeUnknownFailure());
        final container = _container(_Security(), payments);
        final flow = container.read(paymentFlowProvider.notifier)
          ..begin(sampleDetails);
        async.flushMicrotasks();
        unawaited(flow.confirm());
        async.flushMicrotasks();
        payments.snapshot = Success(terminal);
        async.elapse(const Duration(milliseconds: 250));
        expect(flow.state.phase, PaymentFlowPhase.result);
        final reads = payments.snapshots.length;
        async.elapse(paymentReconciliationWindow);
        expect(payments.snapshots, hasLength(reads));
        container.dispose();
        async.flushMicrotasks();
        expectNoPendingTimers(async);
      });
    });
  }

  test('expiry and bill replacement ignore an in-flight snapshot', () {
    fakeAsync((async) {
      final payments = _Payments()
        ..startAnswer = const Err(PaymentOutcomeUnknownFailure())
        ..snapshotAnswer = Completer<Result<PaymentProgress>>();
      final container = _container(_Security(), payments);
      final flow = container.read(paymentFlowProvider.notifier)
        ..begin(sampleDetails);
      async.flushMicrotasks();
      unawaited(flow.confirm());
      async.flushMicrotasks();
      async.elapse(paymentReconciliationWindow);
      payments.snapshotAnswer?.complete(
        const Success(
          PaymentCancelled(paymentId: 'bill-1', attemptId: 'attempt-1'),
        ),
      );
      async.flushMicrotasks();
      expect((flow.state as PaymentFlowCheckingStatus).expired, isTrue);
      flow.begin(detailsWith([usdItem(900)]));
      async.flushMicrotasks();
      expect(flow.state, const PaymentFlowReady());
      container.dispose();
      async.flushMicrotasks();
      expectNoPendingTimers(async);
    });
  });

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
        (flow.state as PaymentFlowCheckingStatus).cancellationFailure,
        const PlatformFailure('UNAVAILABLE'),
      );
    });
  });
}
