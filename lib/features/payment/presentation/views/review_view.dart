import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/features/payment/di/payment_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/sections/payment_section_registry.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/content_width.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/pay_action_bar.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/security_scan_slot.dart';

/// The bill before paying: the security card and the brand's sections in one
/// lazy scroll view, with the pay action pinned below.
class ReviewView extends ConsumerWidget {
  const ReviewView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specs = ref.watch(
      paymentScreenConfigProvider.select((config) => config.sections),
    );
    final registry = ref.watch(paymentSectionRegistryProvider);
    final gap = context.brandDensity.spaceMd;

    return ContentWidth(
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.all(gap),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      for (final sliver in [
                        const SecurityScanSlot(),
                        for (final spec in specs) registry.build(context, spec),
                      ])
                        SliverPadding(
                          padding: EdgeInsets.only(bottom: gap),
                          sliver: sliver,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const PayActionBar(),
        ],
      ),
    );
  }
}
