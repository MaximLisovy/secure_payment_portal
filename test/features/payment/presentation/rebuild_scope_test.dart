import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_config.dart';
import 'package:secure_payment_portal/features/payment/presentation/pages/payment_confirmation_page.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/pay_action_bar.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/payment_body.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/phase_switcher.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/processing_view.dart';

import '../helpers/payment_ui_harness.dart';

/// Which widget types rebuild while [body] runs.
Future<List<Type>> _rebuiltDuring(Future<void> Function() body) async {
  final rebuilt = <Type>[];
  debugOnRebuildDirtyWidget = (element, _) =>
      rebuilt.add(element.widget.runtimeType);
  try {
    await body();
  } finally {
    debugOnRebuildDirtyWidget = null;
  }
  return rebuilt;
}

void main() {
  testWidgets('a progress tick rebuilds the readout and nothing above it', (
    tester,
  ) async {
    await tester.pumpPaymentPage(
      brand: retailBrand,
      payments: const FakePaymentConfig(
        stepDelay: Duration(milliseconds: 100),
        steps: 20,
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(PayActionBar),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(AppStrings.processingTitle), findsOneWidget);
    final before = tester.widget<Text>(find.textContaining('%')).data;

    final rebuilt = await _rebuiltDuring(() async {
      for (var tick = 0; tick < 5; tick++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    expect(tester.widget<Text>(find.textContaining('%')).data, isNot(before));
    expect(rebuilt, contains(ValueListenableBuilder<int>));
    for (final heavy in [
      PaymentConfirmationPage,
      PaymentBody,
      PhaseSwitcher,
      ProcessingView,
    ]) {
      expect(
        rebuilt,
        isNot(contains(heavy)),
        reason: '$heavy rebuilt on a tick',
      );
    }

    await tester.unmountApp();
  });
}
