import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/content_width.dart';

/// No retry action: an unreadable outcome does not prove the payment failed.
class CheckingPaymentStatusView extends ConsumerWidget {
  const CheckingPaymentStatusView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      paymentFlowProvider.select(
        (state) => state is PaymentFlowCheckingStatus ? state : null,
      ),
    );
    if (status == null) return const SizedBox.shrink();
    final density = context.brandDensity;
    return ContentWidth(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(density.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  status.expired
                      ? AppStrings.paymentStatusUnconfirmed
                      : AppStrings.checkingPaymentStatus,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              SizedBox(height: density.spaceMd),
              Text(
                status.expired
                    ? AppStrings.paymentStatusGuidance
                    : AppStrings.paymentStatusCheckingHint,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: density.spaceLg),
              OutlinedButton(
                onPressed: status.cancelRequested
                    ? null
                    : () => ref.read(paymentFlowProvider.notifier).cancel(),
                child: Text(
                  status.cancelRequested
                      ? AppStrings.cancelling
                      : AppStrings.cancel,
                ),
              ),
              if (status.cancellationFailure != null)
                const Text(
                  AppStrings.cancellationStatusUnknown,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
