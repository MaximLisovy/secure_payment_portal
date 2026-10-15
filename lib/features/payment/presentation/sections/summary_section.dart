import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/format/money_formatter.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';

/// Who is paid, what for, and the total.
class SummarySection extends ConsumerWidget {
  const SummarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(loadedPaymentDetailsProvider);
    final density = context.brandDensity;
    final colors = context.brandColors;
    final text = Theme.of(context).textTheme;
    return SliverToBoxAdapter(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(density.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(details.merchantName, style: text.titleMedium),
              SizedBox(height: density.spaceXs),
              Text(
                details.reference,
                style: text.bodyMedium?.copyWith(color: colors.onSurfaceMuted),
              ),
              SizedBox(height: density.spaceMd),
              Text(
                AppStrings.summaryTotal,
                style: text.labelLarge?.copyWith(color: colors.onSurfaceMuted),
              ),
              Text(
                MoneyFormatter.format(details.total),
                style: text.headlineMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
