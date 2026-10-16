import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/security_scan_indicator.dart';

/// The device security card at the top of the review: checking, verified, or the
/// reason payment is blocked. A leaf that watches only the flow state.
class SecurityScanSlot extends ConsumerWidget {
  const SecurityScanSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentFlowProvider);
    final density = context.brandDensity;
    final colors = context.brandColors;
    final text = Theme.of(context).textTheme;

    final (status, title, hint) = switch (state) {
      PaymentFlowIdle() || PaymentFlowSecurityCheck() => (
        ScanIndicatorStatus.checking,
        AppStrings.securityChecking,
        null,
      ),
      PaymentFlowUnavailable() => (
        ScanIndicatorStatus.blocked,
        AppStrings.paymentStatusUnavailable,
        null,
      ),
      PaymentFlowBlocked(:final reason) => (
        ScanIndicatorStatus.blocked,
        AppStrings.message(reason.messageKey),
        AppStrings.blockedHint(reason.messageKey),
      ),
      _ => (ScanIndicatorStatus.verified, AppStrings.securityVerified, null),
    };
    final canRecheck =
        state is PaymentFlowUnavailable ||
        (state is PaymentFlowBlocked && state.reason.isRecoverable);

    return SliverToBoxAdapter(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(density.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SecurityScanIndicator(status: status),
                  SizedBox(width: density.spaceMd),
                  Expanded(
                    // Announced by screen readers when the verdict changes.
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: text.titleSmall),
                          if (hint != null) ...[
                            SizedBox(height: density.spaceXs),
                            Text(
                              hint,
                              style: text.bodyMedium?.copyWith(
                                color: colors.onSurfaceMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (canRecheck) ...[
                SizedBox(height: density.spaceSm),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(paymentFlowProvider.notifier).retry(),
                  child: const Text(AppStrings.checkAgain),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
