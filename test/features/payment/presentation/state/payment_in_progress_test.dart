import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_result.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/security/security_domain.dart';

import '../../helpers/payment_fixtures.dart';
import '../../helpers/payment_ui_harness.dart';

bool _inProgress(PaymentFlowState state) {
  final container = ProviderContainer.test(
    overrides: [fixedFlowOverride(FixedFlow(state))],
  );
  return container.read(paymentInProgressProvider);
}

void main() {
  group('paymentInProgressProvider', () {
    final payment = PaymentResult(
      paymentId: sampleDetails.id,
      transactionId: 'FAKE-TX-000001',
      amount: sampleDetails.total,
      completedAt: DateTime.utc(2026, 10, 15, 12),
      attemptId: 'attempt-1',
    );

    // Every state of the flow, so a new one cannot be forgotten.
    final states = <PaymentFlowState, bool>{
      const PaymentFlowIdle(): false,
      const PaymentFlowSecurityCheck(): false,
      const PaymentFlowBlocked(SecurityBlockReason.rootDetected): false,
      const PaymentFlowReady(): false,
      const PaymentFlowConfirming(): true,
      const PaymentFlowProcessing(percent: 40): true,
      const PaymentFlowProcessing(percent: 40, cancelRequested: true): true,
      PaymentFlowSuccess(payment): false,
      const PaymentFlowFailure(NetworkFailure()): false,
      const PaymentFlowCancelled(): false,
    };

    for (final MapEntry(key: state, value: expected) in states.entries) {
      test('${state.runtimeType} is ${expected ? '' : 'not '}in progress', () {
        expect(_inProgress(state), expected);
      });
    }
  });
}
