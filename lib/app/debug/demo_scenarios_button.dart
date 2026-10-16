import 'dart:async';

import 'package:flutter/material.dart';
import 'package:secure_payment_portal/app/debug/demo_scenarios_panel.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';

/// Opens the demo scenarios panel, and closes it when pressed again. Mount it
/// only behind `!kReleaseMode`, in the app bar of a [Scaffold].
///
/// The panel is a persistent bottom sheet, not a modal one: it has no barrier,
/// so the app bar (the SIMULATED badge, this button, the brand switcher) stays
/// tappable while it is open. The Scaffold caps its height at the area below
/// the app bar, and the panel scrolls inside that.
class DemoScenariosButton extends StatefulWidget {
  const DemoScenariosButton({super.key});

  @override
  State<DemoScenariosButton> createState() => _DemoScenariosButtonState();
}

class _DemoScenariosButtonState extends State<DemoScenariosButton> {
  PersistentBottomSheetController? _sheet;

  void _toggle() {
    final open = _sheet;
    if (open != null) {
      open.close();
      return;
    }
    final controller = Scaffold.of(
      context,
    ).showBottomSheet((_) => const DemoScenariosPanel(), showDragHandle: true);
    _sheet = controller;
    unawaited(
      controller.closed.then((_) {
        if (_sheet == controller) _sheet = null;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppStrings.demoScenarios,
      icon: const Icon(Icons.tune),
      onPressed: _toggle,
    );
  }
}
