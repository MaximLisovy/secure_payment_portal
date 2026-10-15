import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';

class DetailsLoadingView extends StatelessWidget {
  const DetailsLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final density = context.brandDensity;
    return Center(
      child: Semantics(
        label: AppStrings.detailsLoading,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: density.spaceMd),
            Text(
              AppStrings.detailsLoading,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
