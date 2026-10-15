import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
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
    final paymentMode = ref.watch(paymentSourceModeProvider);

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
            _Section(
              title: AppStrings.demoSecuritySection,
              children: [
                _ModePicker(
                  mode: securityMode,
                  realAvailable: ref
                      .read(securitySourceModeProvider.notifier)
                      .realAvailable,
                  onSelected: (mode) => _apply(
                    () => ref
                        .read(securitySourceModeProvider.notifier)
                        .select(mode),
                  ),
                ),
                if (security != null) ...[
                  _Choice<DeviceScenario>(
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
            _Section(
              title: AppStrings.demoPaymentSection,
              children: [
                _ModePicker(
                  mode: paymentMode,
                  realAvailable: ref
                      .read(paymentSourceModeProvider.notifier)
                      .realAvailable,
                  onSelected: (mode) => _apply(
                    () => ref
                        .read(paymentSourceModeProvider.notifier)
                        .select(mode),
                  ),
                ),
                if (payment != null)
                  // Applies to the next payment: no restart.
                  _Choice<PaymentScenario>(
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
            _Section(
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final density = context.brandDensity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: density.spaceLg),
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        SizedBox(height: density.spaceSm),
        ...children,
      ],
    );
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({
    required this.mode,
    required this.realAvailable,
    required this.onSelected,
  });

  final SourceMode mode;
  final bool realAvailable;
  final ValueChanged<SourceMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SourceMode>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: SourceMode.real,
          label: const Text(AppStrings.demoSourceReal),
          enabled: realAvailable,
        ),
        const ButtonSegment(
          value: SourceMode.simulated,
          label: Text(AppStrings.demoSourceSimulated),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => onSelected(selection.single),
    );
  }
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.values,
    required this.selected,
    required this.nameOf,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) nameOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final density = context.brandDensity;
    return Padding(
      padding: EdgeInsets.only(top: density.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          SizedBox(height: density.spaceXs),
          Wrap(
            spacing: density.spaceSm,
            children: [
              for (final value in values)
                ChoiceChip(
                  label: Text(nameOf(value)),
                  selected: value == selected,
                  onSelected: (_) => onSelected(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
