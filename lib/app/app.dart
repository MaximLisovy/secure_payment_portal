import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/app/brand/brand_providers.dart';
import 'package:secure_payment_portal/app/brand_preview/brand_preview_page.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final title = ref.watch(
      activeBrandProvider.select((brand) => brand.displayName),
    );
    // MaterialApp sits above the Theme, so it reads the brand's theme-switch
    // timing straight from the active brand's tokens.
    final motion = ref.watch(
      activeBrandProvider.select((brand) => brand.tokens.motion),
    );
    return MaterialApp(
      title: title,
      theme: theme,
      themeAnimationDuration: motion.medium,
      themeAnimationCurve: motion.standard,
      debugShowCheckedModeBanner: false,
      home: const BrandPreviewPage(),
    );
  }
}
