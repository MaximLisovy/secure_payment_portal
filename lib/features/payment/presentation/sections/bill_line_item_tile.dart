import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/format/money_formatter.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';

/// One line of the bill, sized by the parent (the list gives every row the
/// brand's row height).
class BillLineItemTile extends StatelessWidget {
  const BillLineItemTile({required this.item, super.key});

  final BillLineItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.brandColors;
    final density = context.brandDensity;
    final text = Theme.of(context).textTheme;
    // Taxes and fees read as secondary; charges and discounts as the bill itself.
    final secondary =
        item.kind == LineItemKind.tax || item.kind == LineItemKind.fee;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: density.spaceMd),
      child: Row(
        children: [
          if (item.kind == LineItemKind.discount) ...[
            // The color is an icon, not text, so 3:1 is enough on the surface.
            Icon(
              Icons.sell_outlined,
              size: density.spaceLg,
              color: colors.success,
            ),
            SizedBox(width: density.spaceSm),
          ],
          Expanded(
            child: Text(
              item.label,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(
                color: secondary ? colors.onSurfaceMuted : colors.onSurface,
              ),
            ),
          ),
          SizedBox(width: density.spaceMd),
          Text(MoneyFormatter.format(item.amount), style: text.bodyMedium),
        ],
      ),
    );
  }
}
