import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/app/payment/payment_request_providers.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_bills.dart';
import 'package:secure_payment_portal/features/payment/di/payment_providers.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';

import 'helpers/native_payment_harness.dart';

/// The payment flow on a device, through the real Kotlin plugin and foreground
/// service (no fakes on the payment side, and real device security except where a
/// scenario holds the final security read).
///
/// Per registered brand: a payment is cancelled and retried, and only the new
/// attempt completes (no late event of the cancelled one reaches the receipt);
/// and a payment whose request changes while the final security read is pending
/// never starts.
///
/// Run it on an **emulator** (the driver grants the notification permission with
/// `adb`, and refuses a physical phone), from the project root:
///
/// ```
/// PAYMENT_TEST_DEVICE=emulator-5554 PAYMENT_TEST_FLAVOR=retail \
///   flutter drive --debug --no-dds --flavor retail -d emulator-5554 \
///   --driver=test_driver/payment_integration.dart \
///   --target=integration_test/payment_flow_test.dart
/// ```
///
/// One build covers every brand, because the brand is injected in process. It
/// takes about 30 seconds and writes `build/payment_integration/<flavor>.json`. It
/// needs a device, so CI does not run it.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  binding.reportData = <String, dynamic>{
    'completedScenarios': <String>[],
    'paymentProcessing': 'real Android MethodChannel/EventChannel and service',
    'deviceSecurity':
        'real; final read gated only in obsolete-request scenarios',
  };

  for (final brand in BrandRegistry.standard.all) {
    testWidgets(
      '${brand.id}: native cancel/retry completes only the new attempt',
      (tester) async {
        final env = await mountNativeApp(tester, brand);
        final container = env.container;
        final events = <PaymentProgress>[];
        final subscription = container
            .read(paymentRepositoryProvider)
            .watchProgress()
            .listen(events.add);
        addTearDown(subscription.cancel);
        await pumpUntil(
          tester,
          () => events.isNotEmpty,
          'native stream replay',
        );

        await tapPay(tester);
        await pumpUntil(
          tester,
          () => events.whereType<PaymentInProgress>().isNotEmpty,
          'first native attempt',
        );
        final first = events.whereType<PaymentInProgress>().last;
        await pumpUntil(
          tester,
          () => container.read(paymentFlowProvider) is PaymentFlowProcessing,
          'processing UI',
        );
        await tester.tap(
          find.widgetWithText(OutlinedButton, AppStrings.cancel),
        );
        await pumpUntil(
          tester,
          () => container.read(paymentFlowProvider) is PaymentFlowCancelled,
          'native cancellation',
        );
        expect(
          events.whereType<PaymentCancelled>().last.attemptId,
          first.attemptId,
        );

        await tester.tap(find.text(AppStrings.tryAgain));
        await pumpUntil(
          tester,
          () => container.read(paymentFlowProvider) is PaymentFlowReady,
          'retry review',
        );
        await tapPay(tester);
        await pumpUntil(
          tester,
          () => events.whereType<PaymentInProgress>().any(
            (event) => event.attemptId != first.attemptId,
          ),
          'replacement attempt',
        );
        final second = events.whereType<PaymentInProgress>().last;
        expect(second.paymentId, first.paymentId);
        expect(second.attemptId, isNot(first.attemptId));
        await pumpUntil(
          tester,
          () => container.read(paymentFlowProvider) is PaymentFlowSuccess,
          'native receipt',
        );
        final successes = events
            .whereType<PaymentSucceeded>()
            .where((event) => event.attemptId == second.attemptId)
            .toList();
        expect(successes, hasLength(1));
        expect(
          events.whereType<PaymentSucceeded>().where(
            (event) => event.attemptId == first.attemptId,
          ),
          isEmpty,
        );
        expect(find.text(AppStrings.paymentSuccessful), findsOneWidget);
        expect(
          find.text(successes.single.result.transactionId),
          findsOneWidget,
        );
        final details = container.read(loadedPaymentDetailsProvider);
        expect(successes.single.result.amount, details.total);
        (binding.reportData?['completedScenarios'] as List<String>).add(
          '${brand.id}: native cancel/retry and receipt',
        );
        await subscription.cancel();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      '${brand.id}: changed host request cannot start obsolete payment',
      (tester) async {
        final env = await mountNativeApp(tester, brand, gateSecurity: true);
        final container = env.container;
        final security =
            env.security ?? (throw StateError('gate not installed'));
        final events = <PaymentProgress>[];
        final subscription = container
            .read(paymentRepositoryProvider)
            .watchProgress()
            .listen(events.add);
        addTearDown(subscription.cancel);
        await pumpUntil(
          tester,
          () => events.isNotEmpty,
          'native stream replay',
        );
        events.clear();
        security.holdNextRead();
        await tapPay(tester);
        await pumpUntil(tester, () => security.entered, 'final security read');
        expect(
          container.read(paymentFlowProvider),
          isA<PaymentFlowConfirming>(),
        );
        final oldId = container.read(paymentIdProvider);
        final newId = FakeBills.all.keys.firstWhere((id) => id != oldId);
        container.read(selectedPaymentIdProvider.notifier).select(newId);
        // Release while the replacement bill is still loading, not after begin().
        await security.release();
        await pumpUntil(
          tester,
          () =>
              container.read(paymentDetailsProvider).value?.id == newId &&
              container.read(paymentFlowProvider) is PaymentFlowReady,
          'new request review',
        );
        await tester.pump();
        expect(container.read(paymentFlowProvider), isA<PaymentFlowReady>());
        expect(events.whereType<PaymentInProgress>(), isEmpty);
        (binding.reportData?['completedScenarios'] as List<String>).add(
          '${brand.id}: obsolete request blocked',
        );
        expect(
          find.text(FakeBills.all[newId]?.reference ?? ''),
          findsOneWidget,
        );
        await subscription.cancel();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
