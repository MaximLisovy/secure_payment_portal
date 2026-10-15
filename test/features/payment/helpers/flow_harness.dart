import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:secure_payment_portal/features/payment/data/datasources/fake_bills.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_config.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_details_dto.dart';
import 'package:secure_payment_portal/features/payment/di/payment_data_source_providers.dart';
import 'package:secure_payment_portal/features/payment/di/payment_providers.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_scenario.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_notifier.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';
import 'package:secure_payment_portal/features/security/security.dart';

import 'payment_fixtures.dart';

/// Step between progress updates of the harness's fake payment, and how many.
const harnessStep = Duration(milliseconds: 100);
const harnessSteps = 2;

/// `sampleDetails` as the fake backend would serve it.
final harnessBillDto = PaymentDetailsDto(
  id: sampleDetails.id,
  merchantName: sampleDetails.merchantName,
  reference: sampleDetails.reference,
  currency: 'USD',
  lineItems: [
    for (final item in sampleDetails.lineItems)
      BillLineItemDto(
        label: item.label,
        amountMinor: item.amount.minorUnits,
        kind: item.kind.name,
      ),
  ],
);

final harnessClock = DateTime.utc(2026, 10, 15, 12);

/// The payment flow wired to the fakes, with every state it passes through
/// recorded. Create it inside `fakeAsync`.
final class FlowHarness {
  FlowHarness._(this.container, this.security, this.payments, this.states);

  factory FlowHarness.create({
    PaymentScenario outcome = PaymentScenario.success,
    FakeSecurityPlatformDataSource? security,
    List<Override> overrides = const [],
    FakePaymentRemoteDataSource? remote,
  }) {
    final device = security ?? FakeSecurityPlatformDataSource();
    final payments = FakePaymentPlatformDataSource(
      config: FakePaymentConfig(
        stepDelay: harnessStep,
        steps: harnessSteps,
        scenario: outcome,
      ),
      now: () => harnessClock,
    );
    final container = ProviderContainer.test(
      overrides: [
        paymentScreenConfigProvider.overrideWithValue(
          PaymentScreenConfig(
            paymentId: sampleDetails.id,
            sections: const [SummarySpec()],
          ),
        ),
        securityPlatformDataSourceProvider.overrideWithValue(device),
        paymentPlatformDataSourceProvider.overrideWithValue(payments),
        paymentRemoteDataSourceProvider.overrideWithValue(
          remote ??
              FakePaymentRemoteDataSource(
                bills: {...FakeBills.all, sampleDetails.id: harnessBillDto},
              ),
        ),
        ...overrides,
      ],
    );
    final states = <PaymentFlowState>[];
    container.listen(
      paymentFlowProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    return FlowHarness._(container, device, payments, states);
  }

  final ProviderContainer container;
  final FakeSecurityPlatformDataSource security;
  final FakePaymentPlatformDataSource payments;
  final List<PaymentFlowState> states;

  PaymentFlowNotifier get flow => container.read(paymentFlowProvider.notifier);

  /// What `SecureScreen` does when the page is shown.
  void protectWindow(FakeAsync async) {
    unawaited(container.read(secureWindowProvider.notifier).acquire());
    async.flushMicrotasks();
  }

  /// Starts the flow for [details] and lets it settle.
  void begin(FakeAsync async, [PaymentDetails? details]) {
    flow.begin(details ?? sampleDetails);
    async.flushMicrotasks();
  }

  void confirm(FakeAsync async, [Duration elapse = Duration.zero]) {
    unawaited(flow.confirm());
    async.elapse(elapse);
    async.flushMicrotasks();
  }
}
