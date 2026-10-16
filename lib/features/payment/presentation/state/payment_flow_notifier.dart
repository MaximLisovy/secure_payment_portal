import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/features/payment/di/payment_providers.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_failures.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_confirmation_cancellation.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_reconciliation.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/scan_dwell_provider.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/verdict_hold.dart';
import 'package:secure_payment_portal/features/security/security.dart';

// Native progress replays immediately; 5 s tolerates channel activation without
// leaving platforms with no plugin scanning indefinitely.
const paymentStartupFirstEventDeadline = Duration(seconds: 5);

/// Owns one bill and one payment attempt at a time. Side effects live in methods.
/// A changed bill or disposal invalidates confirmation before it can start work.
/// Only matching attempt events may advance processing; an acceptance error is
/// authoritative even if an optimistic progress event arrived before the reply.
///
/// Security verdicts are held until a scan revolution ends. The hold never
/// delays the final security read after permission preparation, and a recording
/// that starts after processing was accepted does not cancel an authorized payment.
class PaymentFlowNotifier extends Notifier<PaymentFlowState> {
  PaymentDetails? _details;
  StreamSubscription<PaymentProgress>? _progressSubscription;
  StreamSubscription<SecurityStatus>? _statusSubscription;
  bool _awaitingFirstProgress = false;
  Timer? _startupDeadline;
  int _confirmationGeneration = 0;
  PaymentConfirmationCancellation? _confirmationCancellation;
  String? _activeAttemptId;
  final _reconciliation = PaymentReconciliation();

  /// Bumped to drop a device check that is still waiting for the secure window.
  int _checkGeneration = 0;

  /// Holds the verdict of the check until a revolution of the scan ends.
  late final VerdictHold<PaymentFlowState> _hold = VerdictHold(_showVerdict);

  @override
  PaymentFlowState build() {
    // Invalidate confirmation immediately, before replacement details arrive.
    ref.watch(paymentIdProvider);
    ref.onDispose(_stopListening);
    return const PaymentFlowIdle();
  }

  /// Starts the flow for a loaded bill. Calling it again for the same bill does
  /// nothing; a different bill restarts the flow.
  void begin(PaymentDetails details) {
    if (_details?.id == details.id && state is! PaymentFlowIdle) return;
    _stopListening();
    _details = details;
    state = const PaymentFlowIdle();
    _awaitingFirstProgress = true;
    _startupDeadline = Timer(paymentStartupFirstEventDeadline, () {
      if (!ref.mounted || !_awaitingFirstProgress) return;
      state = const PaymentFlowUnavailable();
    });
    _progressSubscription = ref
        .read(paymentRepositoryProvider)
        .watchProgress()
        .listen(
          _onProgress,
          onError: (Object error, StackTrace stackTrace) {
            _onProgress(const PaymentFailed(PaymentOutcomeUnknownFailure()));
          },
          onDone: _checkPaymentStatus,
        );
  }

  /// Confirms the payment. Only from [PaymentFlowReady].
  Future<void> confirm() async {
    final details = _details;
    if (details == null || state is! PaymentFlowReady) return;
    final generation = ++_confirmationGeneration;
    _confirmationCancellation?.cancel();
    final cancellation = PaymentConfirmationCancellation(
      details.id,
      () => ref.read(paymentIdProvider),
    );
    _confirmationCancellation = cancellation;
    final attemptId = ref.read(paymentAttemptIdFactoryProvider)();
    _activeAttemptId = attemptId;
    state = const PaymentFlowConfirming();

    final result = await ref.read(confirmPaymentProvider)(
      details,
      attemptId: attemptId,
      cancellation: cancellation,
    );
    if (!ref.mounted || generation != _confirmationGeneration) return;

    switch (result) {
      case Success<void>():
        // The progress stream usually got there first.
        if (state is PaymentFlowConfirming) {
          state = const PaymentFlowProcessing(percent: 0);
        }
      case Err<void>(:final failure):
        // A pre-acceptance progress event cannot erase a command rejection.
        if (failure is PaymentOutcomeUnknownFailure) {
          _checkPaymentStatus();
          return;
        }
        _reconciliation.stop();
        _activeAttemptId = null;
        state = switch (failure) {
          SecurityBlockedFailure(:final reason) => PaymentFlowBlocked(reason),
          _ => PaymentFlowFailure(failure),
        };
    }
  }

  /// Asks the platform to cancel. The progress stream confirms it.
  Future<void> cancel() async {
    final current = state;
    final requested = switch (current) {
      PaymentFlowProcessing(:final cancelRequested) ||
      PaymentFlowCheckingStatus(:final cancelRequested) => cancelRequested,
      _ => true,
    };
    if (requested) return;
    final attemptId = _activeAttemptId;
    if (attemptId == null) return;
    _setCancellation(requested: true);

    final result = await ref
        .read(paymentRepositoryProvider)
        .cancelPayment(attemptId: attemptId);
    if (!ref.mounted || _activeAttemptId != attemptId) return;
    if (result is Err<void>) {
      _setCancellation(requested: false, failure: result.failure);
      _checkPaymentStatus();
    }
  }

  void _setCancellation({required bool requested, Failure? failure}) {
    state = switch (state) {
      final PaymentFlowProcessing current => current.copyWith(
        cancelRequested: requested,
        cancellationFailure: failure,
        clearCancellationFailure: failure == null,
      ),
      final PaymentFlowCheckingStatus current => current.copyWith(
        cancelRequested: requested,
        cancellationFailure: failure,
        clearCancellationFailure: failure == null,
      ),
      final current => current,
    };
  }

  /// Tries again after a failure, a cancel, or a block that can lift. Also asks
  /// for screen protection once more, in case that is why it was blocked.
  Future<void> retry() async {
    final current = state;
    if (current is PaymentFlowUnavailable) {
      final details = _details;
      _details = null;
      if (details != null) begin(details);
      return;
    }
    final canRetry =
        current is PaymentFlowFailure ||
        current is PaymentFlowCancelled ||
        (current is PaymentFlowBlocked && current.reason.isRecoverable);
    if (!canRetry) return;
    await _restart();
  }

  /// Repeats the same bill after success; the demo does not create a new order.
  Future<void> repeatPayment() async {
    if (state is! PaymentFlowSuccess) return;
    await _restart();
  }

  Future<void> _restart() async {
    final generation = _confirmationGeneration;
    await ref.read(secureWindowProvider.notifier).retry();
    if (!ref.mounted || generation != _confirmationGeneration) return;
    unawaited(_startSecurityCheck());
  }

  Future<void> _startSecurityCheck() async {
    state = const PaymentFlowSecurityCheck();
    final generation = ++_checkGeneration;
    unawaited(_statusSubscription?.cancel());
    _statusSubscription = null;
    _hold.start(ref.read(scanDwellProvider));
    // The device status says whether the window is protected, so it is read only
    // once the window has answered. A failed answer is read and blocks payment;
    // an answer that has not come yet must not.
    await ref.read(secureWindowProvider.notifier).settled();
    if (!ref.mounted || generation != _checkGeneration) return;
    _statusSubscription = ref
        .read(securityStatusRepositoryProvider)
        .watchStatus()
        .listen(
          _onStatus,
          onError: (Object error, StackTrace stackTrace) {
            _onStatus(SecurityStatus.unknown);
          },
        );
  }

  void _onStatus(SecurityStatus status) {
    if (!ref.mounted) return;
    final current = state;
    final reviewing =
        current is PaymentFlowSecurityCheck ||
        current is PaymentFlowReady ||
        current is PaymentFlowBlocked;
    if (!reviewing) return;
    final verdict = switch (ref.read(securityPolicyProvider).evaluate(status)) {
      SecurityAllowed() => const PaymentFlowReady(),
      SecurityBlocked(:final reason) => PaymentFlowBlocked(reason),
    };
    if (current is PaymentFlowSecurityCheck && _hold.isHolding) {
      _hold.hold(verdict);
      return;
    }
    state = verdict;
  }

  /// A revolution ended while the check was shown: show what it found.
  void _showVerdict(PaymentFlowState verdict) {
    if (!ref.mounted || state is! PaymentFlowSecurityCheck) return;
    state = verdict;
  }

  void _onProgress(PaymentProgress progress) {
    if (!ref.mounted) return;
    if (_awaitingFirstProgress) {
      _startupDeadline?.cancel();
      _awaitingFirstProgress = false;
      _onFirstProgress(progress);
      return;
    }
    final paying =
        state is PaymentFlowConfirming ||
        state is PaymentFlowProcessing ||
        state is PaymentFlowCheckingStatus;
    if (!paying) return;
    if (progress is PaymentFailed &&
        (progress.attemptId == null || progress.paymentId == null)) {
      _checkPaymentStatus();
      return;
    }
    if (progress.attemptId != _activeAttemptId ||
        progress.paymentId != _details?.id) {
      return;
    }
    switch (progress) {
      case PaymentIdle():
        break;
      case PaymentInProgress(:final percent):
        if (state is PaymentFlowCheckingStatus) return;
        final current = state;
        state = PaymentFlowProcessing(
          percent: percent,
          cancelRequested:
              current is PaymentFlowProcessing && current.cancelRequested,
          cancellationFailure: current is PaymentFlowProcessing
              ? current.cancellationFailure
              : null,
        );
      case PaymentSucceeded(:final result):
        _finishAttempt();
        state = PaymentFlowSuccess(result);
      case PaymentFailed(:final failure):
        _finishAttempt();
        state = PaymentFlowFailure(failure);
      case PaymentCancelled():
        _finishAttempt();
        state = const PaymentFlowCancelled();
    }
  }

  void _checkPaymentStatus() {
    final attemptId = _activeAttemptId;
    if (attemptId == null || state is PaymentFlowCheckingStatus) return;
    final current = state;
    state = PaymentFlowCheckingStatus(
      cancelRequested:
          current is PaymentFlowProcessing && current.cancelRequested,
      cancellationFailure: current is PaymentFlowProcessing
          ? current.cancellationFailure
          : null,
    );
    _reconciliation.start(
      repository: ref.read(paymentRepositoryProvider),
      attemptId: attemptId,
      onProgress: _onProgress,
      onExpired: () {
        if (!ref.mounted || _activeAttemptId != attemptId) return;
        if (state case final PaymentFlowCheckingStatus current) {
          state = current.copyWith(expired: true);
        }
      },
    );
  }

  void _finishAttempt() {
    _reconciliation.stop();
    _activeAttemptId = null;
  }

  /// The stream replays whatever is current when it is first listened to, which
  /// may be left over from an earlier visit or from a payment the service is
  /// still running after the app came back.
  void _onFirstProgress(PaymentProgress progress) {
    final billId = _details?.id;
    switch (progress) {
      case PaymentFailed()
          when progress.attemptId == null || progress.paymentId == null:
        state = const PaymentFlowUnavailable();
        _awaitingFirstProgress = true;
      case PaymentInProgress(:final paymentId, :final percent)
          when paymentId == billId:
        _activeAttemptId = progress.attemptId;
        state = PaymentFlowProcessing(percent: percent);
      case PaymentSucceeded(:final result) when result.paymentId == billId:
        // Restore the receipt; repeating a demo bill is an explicit user action.
        state = PaymentFlowSuccess(result);
      default:
        // Idle, or a result that belongs to something else: start fresh.
        unawaited(_startSecurityCheck());
    }
  }

  void _stopListening() {
    _startupDeadline?.cancel();
    _startupDeadline = null;
    _awaitingFirstProgress = false;
    _reconciliation.stop();
    _confirmationCancellation?.cancel();
    _confirmationCancellation = null;
    _confirmationGeneration++;
    _activeAttemptId = null;
    _hold.stop();
    _checkGeneration++;
    unawaited(_progressSubscription?.cancel());
    unawaited(_statusSubscription?.cancel());
    _progressSubscription = null;
    _statusSubscription = null;
  }
}
