import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/features/payment/presentation/config/payment_section_spec.dart';

/// A promotional banner. Its copy comes from the brand's [PromoBannerSpec]; the
/// colors are the brand's gradient and the text color that reads on it.
class PromoBannerSection extends StatelessWidget {
  const PromoBannerSection({required this.spec, super.key});

  final PromoBannerSpec spec;

  @override
  Widget build(BuildContext context) {
    final colors = context.brandColors;
    final density = context.brandDensity;
    final text = Theme.of(context).textTheme;
    return SliverToBoxAdapter(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: colors.brandGradient,
          borderRadius: context.brandShape.borderRadiusLg,
        ),
        child: Padding(
          padding: EdgeInsets.all(density.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                spec.headline,
                style: text.titleMedium?.copyWith(color: colors.onBrandPrimary),
              ),
              SizedBox(height: density.spaceXs),
              Text(
                spec.body,
                style: text.bodyMedium?.copyWith(color: colors.onBrandPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
