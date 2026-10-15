import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/app/brand/brand_providers.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';

/// Switches the active brand at runtime (demo video, manual QA). It lists the
/// registry generically and never branches on a brand. Mount it only behind
/// `!kReleaseMode`.
class BrandSwitcher extends ConsumerWidget {
  const BrandSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brands = ref.watch(brandRegistryProvider).all.toList();
    final activeId = ref.watch(activeBrandProvider.select((brand) => brand.id));
    return PopupMenuButton<String>(
      tooltip: AppStrings.switchBrand,
      icon: const Icon(Icons.palette_outlined),
      initialValue: activeId,
      onSelected: (id) => ref.read(activeBrandProvider.notifier).select(id),
      itemBuilder: (context) => [
        for (final brand in brands)
          PopupMenuItem<String>(
            value: brand.id,
            child: Text(brand.displayName),
          ),
      ],
    );
  }
}
