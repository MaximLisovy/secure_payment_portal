import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/security/security.dart';

/// What the device reports right now: one read, then live recording changes.
/// It goes through the repository, like the payment flow does, so it is a second
/// listener on the same native subscription.
final deviceReportProvider = StreamProvider.autoDispose<SecurityStatus>(
  (ref) => ref.watch(securityStatusRepositoryProvider).watchStatus(),
);

/// A read-only view of the real device's security status, for a debug build:
/// which root signals fired, whether a recording is detected, whether the window
/// is protected. Shown only while security runs on the real source.
class DemoDeviceReport extends ConsumerWidget {
  const DemoDeviceReport({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(deviceReportProvider);
    final density = context.brandDensity;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(AppStrings.demoReportTitle, style: text.labelLarge),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(deviceReportProvider),
              child: const Text(AppStrings.demoReportRefresh),
            ),
          ],
        ),
        switch (report) {
          AsyncData(:final value) => _Rows(status: value),
          _ => Padding(
            padding: EdgeInsets.symmetric(vertical: density.spaceSm),
            child: const Text(AppStrings.demoReportReading),
          ),
        },
      ],
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.status});

  final SecurityStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Row(AppStrings.demoReportRoot, _root(status.root)),
        _Row(
          AppStrings.demoReportRecording,
          _detection(status.screenRecording),
        ),
        _Row(AppStrings.demoReportWindow, _window(status.windowProtection)),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = context.brandColors.onSurfaceMuted;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.brandDensity.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodyMedium?.copyWith(color: muted)),
          SizedBox(width: context.brandDensity.spaceMd),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

String _root(RootAssessment root) => switch (root) {
  RootClear() => AppStrings.demoReportNotDetected,
  RootUnknown() => AppStrings.demoReportUnknown,
  RootDetected(:final signals) =>
    '${AppStrings.demoReportDetected}: '
        '${(signals.map((signal) => signal.name).toList()..sort()).join(', ')}',
};

String _detection(Detection detection) => switch (detection) {
  Detection.detected => AppStrings.demoReportDetected,
  Detection.notDetected => AppStrings.demoReportNotDetected,
  Detection.unknown => AppStrings.demoReportUnknown,
};

String _window(WindowProtection protection) => switch (protection) {
  WindowProtection.active => AppStrings.demoReportActive,
  WindowProtection.inactive => AppStrings.demoReportInactive,
  WindowProtection.unknown => AppStrings.demoReportUnknown,
};
