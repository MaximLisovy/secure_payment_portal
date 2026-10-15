import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/failure_view.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/receipt_view.dart';

/// Shows how the payment ended: a receipt, a failure, or a cancel.
///
/// Like the processing view it keeps the last *result* state it was given, so
/// while it fades out into a new review it keeps showing what the user saw.
class ResultView extends ConsumerStatefulWidget {
  const ResultView({super.key});

  @override
  ConsumerState<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<ResultView> {
  late PaymentFlowState _shown;

  @override
  void initState() {
    super.initState();
    _shown = ref.read(paymentFlowProvider);
    ref.listenManual(paymentFlowProvider, (_, next) {
      if (next.phase == PaymentFlowPhase.result) {
        setState(() => _shown = next);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.read(paymentFlowProvider.notifier);
    return switch (_shown) {
      PaymentFlowSuccess(:final result) => ReceiptView(result: result),
      PaymentFlowFailure(:final failure) => FailureView.failed(
        context: context,
        message: AppStrings.message(failure.messageKey),
        onRetry: flow.retry,
      ),
      PaymentFlowCancelled() => FailureView.cancelled(
        context: context,
        onRetry: flow.retry,
      ),
      // Not a result: only reachable if the page is built outside the result
      // phase, which the phase switcher never does.
      _ => const SizedBox.shrink(),
    };
  }
}
