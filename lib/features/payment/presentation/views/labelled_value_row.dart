import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';

class LabelledValueRow extends StatelessWidget {
  const LabelledValueRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = context.brandColors.onSurfaceMuted;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.brandDensity.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodyMedium?.copyWith(color: muted)),
          SizedBox(width: context.brandDensity.spaceMd),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
