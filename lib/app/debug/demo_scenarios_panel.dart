import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/app/debug/demo_device_report.dart';
import 'package:secure_payment_portal/app/debug/demo_panel_widgets.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';
import 'package:secure_payment_portal/features/security/security.dart';

/// What the demo panel offers: which sources are real and which simulated, and,
/// for the simulated ones, situations to play.
///
/// It talks only to the sources' mode providers and to the control interfaces
/// that the simulations (and nothing else) implement; it never asks what class a
/// data source is. The controls are plain calls, not observable, so the panel
/// rebuilds itself after using them.
class DemoScenariosPanel extends ConsumerStatefulWidget {
  const DemoScenariosPanel({super.key});

  @override
  ConsumerState<DemoScenariosPanel> createState() => _DemoScenariosPanelState();
}

class _DemoScenariosPanelState extends ConsumerState<DemoScenariosPanel> {
  /// Reload the bill and start the flow over, so a change that is read at the
  /// start of a flow (the device, a source, the backend) takes effect now.
  void _restart() => unawaited(restartPaymentFlow(ref));

  /// Applies [change] to a control, repaints, and restarts the flow.
  void _apply(VoidCallback change, {bool restart = true}) {
    change();
    setState(() {});
    if (restart) _restart();
  }

  @override
  Widget build(BuildContext context) {
    final density = context.brandDensity;
    final text = Theme.of(context).textTheme;
    final security = ref.watch(securityScenarioControlProvider);
    final payment = ref.watch(paymentScenarioControlProvider);
    final backend = ref.watch(billBackendControlProvider);
    final securityMode = ref.watch(securitySourceModeProvider);
    // Kept watched on purpose, though the panel does not read it. A source switch
    // makes the repository stale, and Riverpod refreshes a watched provider before
    // the next frame is built. Without a watcher, the first read inside a widget's
    // build (the device report appearing) would rebuild it there and schedule a
    // refresh in the middle of the build, which Flutter forbids.
    ref.watch(securityStatusRepositoryProvider);
    final paymentMode = ref.watch(paymentSourceModeProvider);
    // A payment belongs to the source that started it: no swapping underneath.
    final paying = ref.watch(paymentInProgressProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          density.spaceMd,
          0,
          density.spaceMd,
          density.spaceMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.demoScenarios, style: text.titleLarge),
            SizedBox(height: density.spaceXs),
            Text(AppStrings.demoIntro, style: text.bodyMedium),
            if (paying) ...[
              SizedBox(height: density.spaceSm),
              Text(
                AppStrings.demoSourcesLocked,
                style: text.bodyMedium?.copyWith(
                  color: context.brandColors.onSurfaceMuted,
                ),
              ),
            ],
            DemoSection(
              title: AppStrings.demoSecuritySection,
              children: [
                DemoModePicker(
                  mode: securityMode,
                  realAvailable: ref
                      .read(securitySourceModeProvider.notifier)
                      .realAvailable,
                  onSelected: paying
                      ? null
                      : (mode) => _apply(
                          () => ref
                              .read(securitySourceModeProvider.notifier)
                              .select(mode),
                        ),
                ),
                // The real device: only to be read. The simulation has controls instead.
                if (security == null) ...[
                  SizedBox(height: density.spaceSm),
                  const DemoDeviceReport(),
                ],
                if (security != null) ...[
                  DemoChoice<DeviceScenario>(
                    label: AppStrings.demoDevice,
                    values: DeviceScenario.values,
                    selected: security.deviceScenario,
                    nameOf: _deviceLabel,
                    onSelected: (scenario) =>
                        _apply(() => security.setDeviceScenario(scenario)),
                  ),
                  // The flow listens for recordings, so no restart is needed.
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(AppStrings.demoRecording),
                    value: security.recordingActive,
                    onChanged: (active) => _apply(
                      () => security.setRecordingActive(active: active),
                      restart: false,
                    ),
                  ),
                ],
              ],
            ),
            DemoSection(
              title: AppStrings.demoPaymentSection,
              children: [
                DemoModePicker(
                  mode: paymentMode,
                  realAvailable: ref
                      .read(paymentSourceModeProvider.notifier)
                      .realAvailable,
                  onSelected: paying
                      ? null
                      : (mode) => _apply(
                          () => ref
                              .read(paymentSourceModeProvider.notifier)
                              .select(mode),
                        ),
                ),
                if (payment != null)
                  // Applies to the next payment: no restart.
                  DemoChoice<PaymentScenario>(
                    label: AppStrings.demoPaymentEnds,
                    values: PaymentScenario.values,
                    selected: payment.scenario,
                    nameOf: _paymentLabel,
                    onSelected: (scenario) => _apply(
                      () => payment.setScenario(scenario),
                      restart: false,
                    ),
                  ),
              ],
            ),
            DemoSection(
              title: AppStrings.demoBillSection,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(AppStrings.demoBackendOnline),
                  value: backend.online,
                  onChanged: (online) =>
                      _apply(() => backend.setOnline(online: online)),
                ),
              ],
            ),
            SizedBox(height: density.spaceMd),
            OutlinedButton(
              onPressed: _restart,
              child: const Text(AppStrings.demoRestart),
            ),
          ],
        ),
      ),
    );
  }
}

String _deviceLabel(DeviceScenario scenario) => switch (scenario) {
  DeviceScenario.clean => AppStrings.demoDeviceClean,
  DeviceScenario.rooted => AppStrings.demoDeviceRooted,
  DeviceScenario.rootedWeakOnly => AppStrings.demoDeviceRootedWeak,
  DeviceScenario.rootUnverifiable => AppStrings.demoDeviceRootUnverifiable,
};

String _paymentLabel(PaymentScenario scenario) => switch (scenario) {
  PaymentScenario.success => AppStrings.demoPaymentSucceeds,
  PaymentScenario.declined => AppStrings.demoPaymentDeclined,
  PaymentScenario.processingFailure => AppStrings.demoPaymentFails,
};
