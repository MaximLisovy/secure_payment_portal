import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_animation.dart';

/// What the security card's leading slot shows.
enum ScanIndicatorStatus { checking, verified, blocked }

/// The status mark at the head of the security card: the scan while the device
/// is being checked, then a still verdict.
///
/// All three statuses sit in the same box, so the card does not change height
/// when the verdict arrives. The scan's ticker belongs to the scan, which this
/// switcher removes once its fade-out ends, so the sweep keeps turning while it
/// fades and nothing ticks afterwards. This widget itself never rebuilds per
/// frame.
class SecurityScanIndicator extends StatelessWidget {
  const SecurityScanIndicator({required this.status, super.key});

  final ScanIndicatorStatus status;

  /// The mark is this many times a control's height: large enough for the
  /// sweep and the pulses to read.
  static const sizeFactor = 1.5;

  @override
  Widget build(BuildContext context) {
    final colors = context.brandColors;
    final density = context.brandDensity;
    final size = density.controlHeight * sizeFactor;
    final iconSize = density.controlHeight * 0.7;
    return SizedBox.square(
      dimension: size,
      child: AnimatedSwitcher(
        duration: context.adaptiveDuration(context.brandMotion.fast),
        child: switch (status) {
          ScanIndicatorStatus.checking => ScanAnimation(
            key: ValueKey(status),
            dimension: size,
          ),
          ScanIndicatorStatus.verified => Icon(
            Icons.verified_user_outlined,
            key: ValueKey(status),
            size: iconSize,
            color: colors.success,
          ),
          ScanIndicatorStatus.blocked => Icon(
            Icons.gpp_bad_outlined,
            key: ValueKey(status),
            size: iconSize,
            color: colors.danger,
          ),
        },
      ),
    );
  }
}
