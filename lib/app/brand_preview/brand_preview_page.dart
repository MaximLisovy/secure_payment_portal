import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/app/brand/brand_providers.dart';
import 'package:secure_payment_portal/app/brand_preview/brand_preview_view.dart';
import 'package:secure_payment_portal/app/brand_preview/brand_switcher.dart';

/// Temporary home screen for the white-label foundation. Replaced by the
/// payment page when that feature lands.
class BrandPreviewPage extends ConsumerWidget {
  const BrandPreviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(
      activeBrandProvider.select((brand) => brand.displayName),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        actions: [if (!kReleaseMode) const BrandSwitcher()],
      ),
      body: const BrandPreviewView(),
    );
  }
}
