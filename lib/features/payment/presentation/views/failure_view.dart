import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/content_width.dart';

/// A full-screen message with one way forward: a failed payment, a cancelled
/// one, or a bill that did not load.
class FailureView extends StatelessWidget {
  const FailureView({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onRetry,
    this.message,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final VoidCallback onRetry;

  /// A payment that failed.
  factory FailureView.failed({
    required BuildContext context,
    required String message,
    required VoidCallback onRetry,
    Key? key,
  }) => FailureView(
    key: key,
    icon: Icons.error_outline,
    iconColor: context.brandColors.danger,
    title: AppStrings.paymentFailed,
    message: message,
    onRetry: onRetry,
  );

  /// A payment the user cancelled.
  factory FailureView.cancelled({
    required BuildContext context,
    required VoidCallback onRetry,
    Key? key,
  }) => FailureView(
    key: key,
    icon: Icons.cancel_outlined,
    iconColor: context.brandColors.onSurfaceMuted,
    title: AppStrings.paymentCancelled,
    onRetry: onRetry,
  );

  @override
  Widget build(BuildContext context) {
    final density = context.brandDensity;
    final text = Theme.of(context).textTheme;
    final detail = message;
    return ContentWidth(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(density.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: density.controlHeight * 1.5, color: iconColor),
              SizedBox(height: density.spaceMd),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: text.titleLarge,
                ),
              ),
              if (detail != null) ...[
                SizedBox(height: density.spaceSm),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: context.brandColors.onSurfaceMuted,
                  ),
                ),
              ],
              SizedBox(height: density.spaceLg),
              FilledButton(
                onPressed: onRetry,
                child: const Text(AppStrings.tryAgain),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
