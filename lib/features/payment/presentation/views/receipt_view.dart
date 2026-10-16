import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/format/date_time_formatter.dart';
import 'package:secure_payment_portal/core/format/money_formatter.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_result.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/content_width.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/labelled_value_row.dart';

/// The receipt after a payment that went through.
class ReceiptView extends ConsumerWidget {
  const ReceiptView({required this.result, super.key});

  final PaymentResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchant = ref.watch(
      loadedPaymentDetailsProvider.select((details) => details.merchantName),
    );
    final density = context.brandDensity;
    final text = Theme.of(context).textTheme;
    return ContentWidth(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(density.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: density.controlHeight * 1.5,
                color: context.brandColors.success,
              ),
              SizedBox(height: density.spaceMd),
              Semantics(
                header: true,
                child: Text(
                  AppStrings.paymentSuccessful,
                  textAlign: TextAlign.center,
                  style: text.titleLarge,
                ),
              ),
              SizedBox(height: density.spaceLg),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(density.spaceMd),
                  child: Column(
                    children: [
                      LabelledValueRow(
                        label: AppStrings.receiptMerchant,
                        value: merchant,
                      ),
                      LabelledValueRow(
                        label: AppStrings.receiptAmount,
                        value: MoneyFormatter.format(result.amount),
                      ),
                      LabelledValueRow(
                        label: AppStrings.receiptTransaction,
                        value: result.transactionId,
                      ),
                      LabelledValueRow(
                        label: AppStrings.receiptTime,
                        value: DateTimeFormatter.utc(result.completedAt),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: density.spaceLg),
              FilledButton(
                onPressed: () =>
                    ref.read(paymentFlowProvider.notifier).repeatPayment(),
                child: const Text(AppStrings.repeatDemoPayment),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
