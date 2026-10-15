import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';

/// What the security card's leading slot shows.
enum ScanIndicatorStatus { checking, verified, blocked }

/// The status mark at the head of the security card, in its own repaint layer so
/// the spinner's frames never repaint the sections around it.
class SecurityScanIndicator extends StatelessWidget {
  const SecurityScanIndicator({required this.status, super.key});

  final ScanIndicatorStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.brandColors;
    final size = context.brandDensity.controlHeight;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: switch (status) {
            ScanIndicatorStatus.checking => SizedBox.square(
              dimension: size * 0.6,
              child: const CircularProgressIndicator(strokeWidth: 3),
            ),
            ScanIndicatorStatus.verified => Icon(
              Icons.verified_user_outlined,
              size: size * 0.7,
              color: colors.success,
            ),
            ScanIndicatorStatus.blocked => Icon(
              Icons.gpp_bad_outlined,
              size: size * 0.7,
              color: colors.danger,
            ),
          },
        ),
      ),
    );
  }
}
