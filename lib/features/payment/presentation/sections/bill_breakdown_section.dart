import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/presentation/sections/bill_line_item_tile.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';

/// The bill's line items as a dense list. It is a sliver with a fixed row
/// extent, so only the rows on screen are built however long the bill is.
class BillBreakdownSection extends ConsumerWidget {
  const BillBreakdownSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(
      loadedPaymentDetailsProvider.select((details) => details.lineItems),
    );
    final colors = context.brandColors;
    final density = context.brandDensity;
    final shape = context.brandShape;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: density.spaceSm),
            child: Text(
              AppStrings.billBreakdownTitle,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: colors.onSurfaceMuted),
            ),
          ),
        ),
        DecoratedSliver(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: shape.borderRadiusMd,
            border: Border.fromBorderSide(
              shape.borderSide(colors.outlineSubtle),
            ),
          ),
          sliver: SliverFixedExtentList.builder(
            itemExtent: density.rowHeight,
            itemCount: items.length,
            itemBuilder: (context, index) =>
                BillLineItemTile(item: items[index]),
          ),
        ),
      ],
    );
  }
}
