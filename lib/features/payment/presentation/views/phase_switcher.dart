import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/processing_view.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/result_view.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/review_view.dart';

/// Swaps between review, processing and result with the brand's motion. It
/// watches only the phase, so the flow's smaller steps rebuild nothing here.
class PhaseSwitcher extends ConsumerWidget {
  const PhaseSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(paymentFlowProvider.select((state) => state.phase));
    final motion = context.brandMotion;
    return AnimatedSwitcher(
      duration: context.adaptiveDuration(motion.medium),
      switchInCurve: motion.emphasized,
      switchOutCurve: motion.standard,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey(phase),
        child: switch (phase) {
          PaymentFlowPhase.review => const ReviewView(),
          PaymentFlowPhase.processing => const ProcessingView(),
          PaymentFlowPhase.result => const ResultView(),
        },
      ),
    );
  }
}
