import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/app/brand/brand_providers.dart';
import 'package:secure_payment_portal/app/debug/brand_switcher.dart';
import 'package:secure_payment_portal/app/debug/demo_scenarios_button.dart';
import 'package:secure_payment_portal/app/debug/frame_stats_collector.dart';
import 'package:secure_payment_portal/app/debug/performance_overlay_provider.dart';
import 'package:secure_payment_portal/app/debug/simulation_badge.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';

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
    final showOverlay = ref.watch(showPerformanceOverlayProvider);
    final app = MaterialApp(
      title: title,
      theme: theme,
      showPerformanceOverlay: showOverlay,
      themeAnimationDuration: motion.medium,
      themeAnimationCurve: motion.standard,
      debugShowCheckedModeBanner: false,
      home: PaymentConfirmationPage(
        title: title,
        appBarActions: [
          // In every build: a simulated app must never pass for a real one.
          const SimulationBadge(),
          if (!kReleaseMode) ...const [DemoScenariosButton(), BrandSwitcher()],
        ],
      ),
    );
    return kReleaseMode ? app : FrameStatsCollector(child: app);
  }
}
