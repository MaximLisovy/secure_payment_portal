import 'package:flutter/material.dart';
import 'package:secure_payment_portal/app/debug/demo_scenarios_panel.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';

/// Opens the demo scenarios panel. Mount it only behind `!kReleaseMode`.
class DemoScenariosButton extends StatelessWidget {
  const DemoScenariosButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppStrings.demoScenarios,
      icon: const Icon(Icons.tune),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const DemoScenariosPanel(),
      ),
    );
  }
}
