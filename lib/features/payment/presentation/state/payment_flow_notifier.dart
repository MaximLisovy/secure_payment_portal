import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/features/payment/di/payment_providers.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/security/security.dart';

/// The payment flow as a state machine.
///
/// `build` only returns [PaymentFlowIdle]; every side effect lives in a method.
/// The notifier composes the status stream with the security policy itself, as
/// decided in the domain milestone, and talks to `ConfirmPayment` only to start
/// processing.
///
/// Transitions: `Idle → SecurityCheck → Ready | Blocked`, `Ready → Confirming →
/// Processing(p) → Success | Failure | Cancelled`, and `Blocked(recoverable)`,
/// `Failure`, `Cancelled` and `Success` go back to `SecurityCheck`. Security
/// changes are applied only before confirming: once a payment is authorized, a
/// recording that starts does not cancel it.
class PaymentFlowNotifier extends Notifier<PaymentFlowState> {
  PaymentDetails? _details;
  StreamSubscription<PaymentProgress>? _progressSubscription;
  StreamSubscription<SecurityStatus>? _statusSubscription;
  bool _awaitingFirstProgress = false;

  /// Bumped to drop a device check that is still waiting for the secure window.
  int _checkGeneration = 0;

  @override
  PaymentFlowState build() {
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
    _progressSubscription = ref
        .read(paymentRepositoryProvider)
        .watchProgress()
        .listen(_onProgress);
  }

  /// Confirms the payment. Only from [PaymentFlowReady].
  Future<void> confirm() async {
    final details = _details;
    if (details == null || state is! PaymentFlowReady) return;
    state = const PaymentFlowConfirming();

    final result = await ref.read(confirmPaymentProvider)(details);
    if (!ref.mounted) return;

    switch (result) {
      case Success<void>():
        // The progress stream usually got there first.
        if (state is PaymentFlowConfirming) {
          state = const PaymentFlowProcessing(percent: 0);
        }
      case Err<void>(:final failure):
        // The progress stream may already have reported the outcome.
        if (state is! PaymentFlowConfirming) return;
        state = switch (failure) {
          SecurityBlockedFailure(:final reason) => PaymentFlowBlocked(reason),
          _ => PaymentFlowFailure(failure),
        };
    }
  }

  /// Asks the platform to cancel. The progress stream confirms it.
  Future<void> cancel() async {
    final current = state;
    if (current is! PaymentFlowProcessing || current.cancelRequested) return;
    state = current.copyWith(cancelRequested: true);

    final result = await ref.read(paymentRepositoryProvider).cancelPayment();
    if (!ref.mounted) return;

    // If the request failed the payment is still running: let the user try again.
    final now = state;
    if (result is Err<void> && now is PaymentFlowProcessing) {
      state = now.copyWith(cancelRequested: false);
    }
  }

  /// Tries again after a failure, a cancel, or a block that can lift. Also asks
  /// for screen protection once more, in case that is why it was blocked.
  Future<void> retry() async {
    final current = state;
    final canRetry =
        current is PaymentFlowFailure ||
        current is PaymentFlowCancelled ||
        (current is PaymentFlowBlocked && current.reason.isRecoverable);
    if (!canRetry) return;
    await _restart();
  }

  /// Starts over after a finished payment.
  Future<void> newPayment() async {
    if (state is! PaymentFlowSuccess) return;
    await _restart();
  }

  Future<void> _restart() async {
    await ref.read(secureWindowProvider.notifier).retry();
    if (!ref.mounted) return;
    unawaited(_startSecurityCheck());
  }

  Future<void> _startSecurityCheck() async {
    state = const PaymentFlowSecurityCheck();
    final generation = ++_checkGeneration;
    unawaited(_statusSubscription?.cancel());
    _statusSubscription = null;
    // The device status says whether the window is protected, so it is read only
    // once the window has answered. A failed answer is read and blocks payment;
    // an answer that has not come yet must not.
    await ref.read(secureWindowProvider.notifier).settled();
    if (!ref.mounted || generation != _checkGeneration) return;
    _statusSubscription = ref
        .read(securityStatusRepositoryProvider)
        .watchStatus()
        .listen(_onStatus);
  }

  void _onStatus(SecurityStatus status) {
    if (!ref.mounted) return;
    final current = state;
    final reviewing =
        current is PaymentFlowSecurityCheck ||
        current is PaymentFlowReady ||
        current is PaymentFlowBlocked;
    if (!reviewing) return;
    state = switch (ref.read(securityPolicyProvider).evaluate(status)) {
      SecurityAllowed() => const PaymentFlowReady(),
      SecurityBlocked(:final reason) => PaymentFlowBlocked(reason),
    };
  }

  void _onProgress(PaymentProgress progress) {
    if (!ref.mounted) return;
    if (_awaitingFirstProgress) {
      _awaitingFirstProgress = false;
      _onFirstProgress(progress);
      return;
    }
    final paying =
        state is PaymentFlowConfirming || state is PaymentFlowProcessing;
    if (!paying) return;
    switch (progress) {
      case PaymentIdle():
        break;
      case PaymentInProgress(:final percent):
        final current = state;
        state = PaymentFlowProcessing(
          percent: percent,
          cancelRequested:
              current is PaymentFlowProcessing && current.cancelRequested,
        );
      case PaymentSucceeded(:final result):
        state = PaymentFlowSuccess(result);
      case PaymentFailed(:final failure):
        state = PaymentFlowFailure(failure);
      case PaymentCancelled():
        state = const PaymentFlowCancelled();
    }
  }

  /// The stream replays whatever is current when it is first listened to, which
  /// may be left over from an earlier visit or from a payment the service is
  /// still running after the app came back.
  void _onFirstProgress(PaymentProgress progress) {
    final billId = _details?.id;
    switch (progress) {
      case PaymentInProgress(:final paymentId, :final percent)
          when paymentId == billId:
        state = PaymentFlowProcessing(percent: percent);
      case PaymentSucceeded(:final result) when result.paymentId == billId:
        // Already paid: show the receipt, never let the bill be paid twice.
        state = PaymentFlowSuccess(result);
      default:
        // Idle, or a result that belongs to something else: start fresh.
        unawaited(_startSecurityCheck());
    }
  }

  void _stopListening() {
    _checkGeneration++;
    unawaited(_progressSubscription?.cancel());
    unawaited(_statusSubscription?.cancel());
    _progressSubscription = null;
    _statusSubscription = null;
  }
}
