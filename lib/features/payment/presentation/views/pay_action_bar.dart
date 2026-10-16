import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/format/money_formatter.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';

/// The pay action, pinned under the scrolling sections so it is always in
/// reach, however long the bill. Enabled only when security allows payment.
class PayActionBar extends ConsumerWidget {
  const PayActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(
      loadedPaymentDetailsProvider.select((details) => details.total),
    );
    final state = ref.watch(paymentFlowProvider);
    final colors = context.brandColors;
    final density = context.brandDensity;
    final confirming = state is PaymentFlowConfirming;
    final enabled = state is PaymentFlowReady;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: context.brandShape.borderSide(colors.outlineSubtle),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(density.spaceMd),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: enabled
                ? () => ref.read(paymentFlowProvider.notifier).confirm()
                : null,
            child: confirming
                ? const Text(AppStrings.confirming)
                : Text(AppStrings.payAction(MoneyFormatter.format(total))),
          ),
        ),
      ),
    );
  }
}
