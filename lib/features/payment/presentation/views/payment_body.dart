import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/error/failure_exception.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/details_loading_view.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/failure_view.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/phase_switcher.dart';

/// The page body: the bill loading, failing to load, or the payment flow.
class PaymentBody extends ConsumerWidget {
  const PaymentBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(paymentDetailsProvider);
    return details.when(
      loading: () => const DetailsLoadingView(),
      error: (error, _) => FailureView(
        icon: Icons.error_outline,
        iconColor: context.brandColors.danger,
        title: AppStrings.message(failureOfError(error).messageKey),
        onRetry: () => ref.invalidate(paymentDetailsProvider),
      ),
      data: (_) => const PhaseSwitcher(),
    );
  }
}
