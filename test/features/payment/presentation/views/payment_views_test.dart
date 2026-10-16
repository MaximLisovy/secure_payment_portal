import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_failures.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_result.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/security/security_domain.dart';

import '../../../../helpers/pump_app.dart';
import '../../helpers/payment_ui_harness.dart';

// The retail brand's bill: 89.00 + 19.00 - 10.80 + 4.99 + 7.20.
const _total = r'$109.39';

final _result = PaymentResult(
  paymentId: 'retail-order-1042',
  transactionId: 'FAKE-TX-000001',
  amount: const Money.minor(10939, Currency.usd),
  completedAt: DateTime.utc(2026, 10, 15, 12),
  attemptId: 'attempt-1',
);

Future<FixedFlow> _pumpIn(
  WidgetTester tester,
  PaymentFlowState state, {
  FakePaymentRemoteDataSource? remote,
}) async {
  final flow = FixedFlow(state);
  await tester.pumpApp(
    const PaymentConfirmationPage(title: 'Shop'),
    brand: retailBrand,
    overrides: [
      fixedFlowOverride(flow),
      ...instantBackend(remote: remote),
    ],
  );
  await tester.pump();
  await tester.pump();
  return flow;
}

Finder _payButton() => find.widgetWithText(FilledButton, 'Pay $_total');

bool _enabled(WidgetTester tester, Finder button) =>
    tester.widget<ButtonStyleButton>(button).onPressed != null;

void main() {
  for (final expired in [false, true]) {
    testWidgets(
      'unknown outcome (expired: $expired) keeps Cancel and has no retry',
      (tester) async {
        final flow = await _pumpIn(
          tester,
          PaymentFlowCheckingStatus(expired: expired),
        );
        expect(
          find.text(
            expired
                ? AppStrings.paymentStatusUnconfirmed
                : AppStrings.checkingPaymentStatus,
          ),
          findsOneWidget,
        );
        expect(find.text(AppStrings.tryAgain), findsNothing);
        await tester.tap(find.text(AppStrings.cancel));
        expect(flow.calls, contains('cancel'));
        expect(flow.calls, isNot(contains('retry')));
      },
    );
  }
  testWidgets('startup unavailable blocks Pay and offers a fresh check', (
    tester,
  ) async {
    final flow = await _pumpIn(tester, const PaymentFlowUnavailable());
    expect(find.text(AppStrings.paymentStatusUnavailable), findsOneWidget);
    expect(_enabled(tester, _payButton()), isFalse);
    expect(find.text(AppStrings.securityVerified), findsNothing);
    await tester.tap(find.text(AppStrings.checkAgain));
    expect(flow.calls, contains('retry'));
  });
  group('review', () {
    testWidgets(
      'shows the scan while the device is being checked, pay disabled',
      (tester) async {
        await _pumpIn(tester, const PaymentFlowSecurityCheck());

        expect(find.text(AppStrings.securityChecking), findsOneWidget);
        expect(_enabled(tester, _payButton()), isFalse);
      },
    );

    testWidgets('the sections of the brand are on screen', (tester) async {
      await _pumpIn(tester, const PaymentFlowReady());

      expect(find.text('Retail Shop'), findsOneWidget);
      expect(find.text('Order #1042'), findsOneWidget);
      expect(find.text('Welcome offer'), findsOneWidget);
    });

    testWidgets('a verified device can pay, and pay asks the flow to confirm', (
      tester,
    ) async {
      final flow = await _pumpIn(tester, const PaymentFlowReady());

      expect(find.text(AppStrings.securityVerified), findsOneWidget);
      expect(_enabled(tester, _payButton()), isTrue);

      await tester.tap(_payButton());

      expect(flow.calls, contains('confirm'));
    });

    testWidgets('while confirming the button says so and cannot be pressed', (
      tester,
    ) async {
      await _pumpIn(tester, const PaymentFlowConfirming());

      final button = find.widgetWithText(FilledButton, AppStrings.confirming);
      expect(button, findsOneWidget);
      expect(_enabled(tester, button), isFalse);
    });

    testWidgets('a block that cannot lift shows its reason and no recheck', (
      tester,
    ) async {
      await _pumpIn(
        tester,
        const PaymentFlowBlocked(SecurityBlockReason.rootDetected),
      );

      expect(
        find.text(AppStrings.message('security.blocked.root_detected')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.checkAgain), findsNothing);
      expect(_enabled(tester, _payButton()), isFalse);
    });

    testWidgets('a block that can lift offers a recheck', (tester) async {
      final flow = await _pumpIn(
        tester,
        const PaymentFlowBlocked(
          SecurityBlockReason.screenProtectionUnavailable,
        ),
      );

      await tester.tap(find.text(AppStrings.checkAgain));

      expect(flow.calls, contains('retry'));
    });

    testWidgets('a screen recording says it continues by itself', (
      tester,
    ) async {
      await _pumpIn(
        tester,
        const PaymentFlowBlocked(SecurityBlockReason.screenRecording),
      );

      expect(
        find.text(AppStrings.blockedHint('security.blocked.screen_recording')!),
        findsOneWidget,
      );
    });

    testWidgets('the pay bar is shown in every review state', (tester) async {
      for (final state in const <PaymentFlowState>[
        PaymentFlowSecurityCheck(),
        PaymentFlowReady(),
        PaymentFlowBlocked(SecurityBlockReason.rootDetected),
      ]) {
        await _pumpIn(tester, state);
        expect(_payButton(), findsOneWidget, reason: '$state');
      }
    });
  });

  group('processing', () {
    testWidgets(
      'a rejected cancel is visible while progress and retry remain',
      (tester) async {
        final flow = await _pumpIn(
          tester,
          const PaymentFlowProcessing(
            percent: 37,
            cancellationFailure: PlatformFailure('UNAVAILABLE'),
          ),
        );
        expect(find.text('37%'), findsOneWidget);
        expect(find.text(AppStrings.cancellationFailed), findsOneWidget);
        final button = find.widgetWithText(OutlinedButton, AppStrings.cancel);
        expect(_enabled(tester, button), isTrue);
        await tester.tap(button);
        expect(flow.calls, contains('cancel'));
      },
    );

    testWidgets('shows the percentage and a cancel button', (tester) async {
      final flow = await _pumpIn(
        tester,
        const PaymentFlowProcessing(percent: 37),
      );

      expect(find.text(AppStrings.processingTitle), findsOneWidget);
      expect(find.text('37%'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.37,
      );

      await tester.tap(find.text(AppStrings.cancel));
      expect(flow.calls, contains('cancel'));
    });

    testWidgets('a requested cancel disables the button', (tester) async {
      await _pumpIn(
        tester,
        const PaymentFlowProcessing(percent: 37, cancelRequested: true),
      );

      final button = find.widgetWithText(OutlinedButton, AppStrings.cancelling);
      expect(button, findsOneWidget);
      expect(_enabled(tester, button), isFalse);
    });
  });

  group('result', () {
    testWidgets('a receipt shows what was paid, and starts a new payment', (
      tester,
    ) async {
      final flow = await _pumpIn(tester, PaymentFlowSuccess(_result));

      expect(find.text(AppStrings.paymentSuccessful), findsOneWidget);
      expect(find.text('Retail Shop'), findsOneWidget);
      expect(find.text(_total), findsOneWidget);
      expect(find.text('FAKE-TX-000001'), findsOneWidget);
      expect(find.text('2026-10-15 12:00 UTC'), findsOneWidget);

      await tester.tap(find.text(AppStrings.repeatDemoPayment));
      expect(flow.calls, contains('repeatPayment'));
    });

    testWidgets('a failed payment says why and offers to try again', (
      tester,
    ) async {
      final flow = await _pumpIn(
        tester,
        const PaymentFlowFailure(PaymentDeclinedFailure()),
      );

      expect(find.text(AppStrings.paymentFailed), findsOneWidget);
      expect(find.text(AppStrings.message('payment.declined')), findsOneWidget);

      await tester.tap(find.text(AppStrings.tryAgain));
      expect(flow.calls, contains('retry'));
    });

    testWidgets('a cancelled payment can be tried again', (tester) async {
      final flow = await _pumpIn(tester, const PaymentFlowCancelled());

      expect(find.text(AppStrings.paymentCancelled), findsOneWidget);

      await tester.tap(find.text(AppStrings.tryAgain));
      expect(flow.calls, contains('retry'));
    });
  });

  group('the bill', () {
    testWidgets('shows a loading state while the bill is fetched', (
      tester,
    ) async {
      final flow = FixedFlow(const PaymentFlowIdle());
      await tester.pumpApp(
        const PaymentConfirmationPage(title: 'Shop'),
        brand: retailBrand,
        overrides: [
          fixedFlowOverride(flow),
          ...instantBackend(
            remote: FakePaymentRemoteDataSource(
              latency: const Duration(seconds: 1),
            ),
          ),
        ],
      );

      expect(find.text(AppStrings.detailsLoading), findsOneWidget);
      expect(_payButton(), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text(AppStrings.detailsLoading), findsNothing);
      expect(flow.calls, ['begin']);
    });

    testWidgets('a bill that fails to load can be fetched again', (
      tester,
    ) async {
      final remote = FakePaymentRemoteDataSource(
        outcome: FakeRemoteOutcome.networkError,
      );
      await _pumpIn(tester, const PaymentFlowIdle(), remote: remote);

      expect(
        find.text(AppStrings.message(const NetworkFailure().messageKey)),
        findsOneWidget,
      );

      remote.outcome = FakeRemoteOutcome.success;
      await tester.tap(find.text(AppStrings.tryAgain));
      await tester.pump();
      await tester.pump();

      expect(find.text('Retail Shop'), findsOneWidget);
    });
  });
}
