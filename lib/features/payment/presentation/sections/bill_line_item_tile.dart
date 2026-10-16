import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/format/money_formatter.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';

/// The most of a row the amount may take. Past it the amount scales down to fit
/// instead of squeezing the label away.
const double billAmountMaxWidthFraction = 0.45;

/// One line of the bill. It is at least the brand's row height and grows with
/// the text scale; the list measures one tile and gives every row that height.
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
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: density.rowHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: density.spaceMd,
          vertical: density.spaceSm,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
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
              _AmountColumn(
                amount: MoneyFormatter.format(item.amount),
                style: text.bodyMedium,
                maxWidth: constraints.maxWidth * billAmountMaxWidthFraction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The amount, kept whole: it takes the room it needs up to a share of the row
/// and scales down past that, never ellipsized, since a cut digit is a wrong
/// amount.
class _AmountColumn extends StatelessWidget {
  const _AmountColumn({
    required this.amount,
    required this.style,
    required this.maxWidth,
  });

  final String amount;
  final TextStyle? style;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerEnd,
        child: Text(amount, style: style, maxLines: 1, softWrap: false),
      ),
    );
  }
}
