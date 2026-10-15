import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/app/debug/simulation_providers.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';

/// A mark in the app bar for as long as any source is simulated, in every build
/// mode: nobody should mistake a simulated build for the real thing.
class SimulationBadge extends ConsumerWidget {
  const SimulationBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(simulationActiveProvider)) return const SizedBox.shrink();
    final colors = context.brandColors;
    final density = context.brandDensity;
    return Semantics(
      label: AppStrings.simulatedBadgeHint,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.danger,
            borderRadius: context.brandShape.borderRadiusSm,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: density.spaceSm,
              vertical: density.spaceXs,
            ),
            child: Text(
              AppStrings.simulatedBadge,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onDanger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
