import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';
import 'package:secure_payment_portal/features/payment/presentation/sections/bill_line_item_tile.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';

/// The bill's line items as a dense list. It is a sliver with one shared row
/// extent, so only the rows on screen are built however long the bill is. The
/// extent is that of a measured tile, so it follows the text scale instead of
/// clipping at a large one.
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
          sliver: SliverPrototypeExtentList.builder(
            prototypeItem: const BillLineItemTile(item: _prototypeItem),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                BillLineItemTile(item: items[index]),
          ),
        ),
      ],
    );
  }
}

/// What the measured tile shows: one line each side, at the text's own height.
const _prototypeItem = BillLineItem(
  label: 'Item',
  amount: Money.zero(Currency.usd),
  kind: LineItemKind.charge,
);
