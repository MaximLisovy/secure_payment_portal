import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/content_width.dart';

/// The payment in progress. Only the percentage and the bar rebuild on a tick.
///
/// The view keeps the *latest processing* values, not the live state: while it
/// fades out into the result, the percentage stays where it ended instead of
/// jumping to a fallback.
class ProcessingView extends ConsumerStatefulWidget {
  const ProcessingView({super.key});

  @override
  ConsumerState<ProcessingView> createState() => _ProcessingViewState();
}

class _ProcessingViewState extends ConsumerState<ProcessingView> {
  final _percent = ValueNotifier<int>(0);
  final _cancelRequested = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _apply(ref.read(paymentFlowProvider));
    ref.listenManual(paymentFlowProvider, (_, next) => _apply(next));
  }

  void _apply(PaymentFlowState state) {
    if (state case PaymentFlowProcessing(
      :final percent,
      :final cancelRequested,
    )) {
      _percent.value = percent;
      _cancelRequested.value = cancelRequested;
    }
  }

  @override
  void dispose() {
    _percent.dispose();
    _cancelRequested.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final density = context.brandDensity;
    final text = Theme.of(context).textTheme;
    return ContentWidth(
      child: Padding(
        padding: EdgeInsets.all(density.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                AppStrings.processingTitle,
                textAlign: TextAlign.center,
                style: text.titleLarge,
              ),
            ),
            SizedBox(height: density.spaceLg),
            _ProgressReadout(percent: _percent),
            SizedBox(height: density.spaceXl),
            _CancelButton(cancelRequested: _cancelRequested),
          ],
        ),
      ),
    );
  }
}

class _ProgressReadout extends StatelessWidget {
  const _ProgressReadout({required this.percent});

  final ValueNotifier<int> percent;

  @override
  Widget build(BuildContext context) {
    final density = context.brandDensity;
    final colors = context.brandColors;
    return ValueListenableBuilder<int>(
      valueListenable: percent,
      builder: (context, value, _) => Semantics(
        label: AppStrings.progressSemantics(value),
        excludeSemantics: true,
        child: RepaintBoundary(
          child: Column(
            children: [
              Text(
                AppStrings.percentLabel(value),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              SizedBox(height: density.spaceMd),
              ClipRRect(
                borderRadius: context.brandShape.borderRadiusSm,
                child: LinearProgressIndicator(
                  value: value / 100,
                  minHeight: density.spaceSm + density.spaceXs,
                  backgroundColor: colors.outlineSubtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelButton extends ConsumerWidget {
  const _CancelButton({required this.cancelRequested});

  final ValueNotifier<bool> cancelRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<bool>(
      valueListenable: cancelRequested,
      builder: (context, requested, _) => OutlinedButton(
        onPressed: requested
            ? null
            : () => ref.read(paymentFlowProvider.notifier).cancel(),
        child: Text(requested ? AppStrings.cancelling : AppStrings.cancel),
      ),
    );
  }
}
