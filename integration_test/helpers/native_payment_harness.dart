import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/app.dart';
import 'package:secure_payment_portal/app/di/root_overrides.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/core/logging/logger_provider.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/features/payment/di/payment_data_source_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/pay_action_bar.dart';
import 'package:secure_payment_portal/features/security/data/repositories/security_status_repository_impl.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';
import 'package:secure_payment_portal/features/security/security.dart';

/// Only the final security read is gated. All underlying device calls are real.
class GatedSecurity implements SecurityStatusRepository {
  GatedSecurity(this.delegate);

  final SecurityStatusRepository delegate;
  Completer<Result<SecurityStatus>>? _pending;
  bool entered = false;

  void holdNextRead() {
    entered = false;
    _pending = Completer<Result<SecurityStatus>>();
  }

  Future<void> release() async {
    final pending = _pending;
    _pending = null;
    pending?.complete(await delegate.getStatus());
  }

  @override
  Future<Result<SecurityStatus>> getStatus() {
    final pending = _pending;
    if (pending == null) return delegate.getStatus();
    entered = true;
    return pending.future;
  }

  @override
  Stream<SecurityStatus> watchStatus() => delegate.watchStatus();
}

Future<({ProviderContainer container, GatedSecurity? security})> mountNativeApp(
  WidgetTester tester,
  BrandConfig brand, {
  bool gateSecurity = false,
}) async {
  GatedSecurity? security;
  await tester.pumpWidget(
    ProviderScope(
      retry: disableProviderRetry,
      overrides: [
        ...rootOverrides(initialBrand: brand),
        if (gateSecurity)
          securityStatusRepositoryProvider.overrideWith((ref) {
            return security = GatedSecurity(
              SecurityStatusRepositoryImpl(
                ref.watch(securityPlatformDataSourceProvider),
                logger: ref.watch(loggerProvider),
              ),
            );
          }),
      ],
      child: const App(),
    ),
  );
  final container = ProviderScope.containerOf(tester.element(find.byType(App)));
  expect(container.read(paymentSourceModeProvider), SourceMode.real);
  expect(container.read(securitySourceModeProvider), SourceMode.real);
  await pumpUntil(tester, () {
    final state = container.read(paymentFlowProvider);
    return state is PaymentFlowReady ||
        state is PaymentFlowSuccess ||
        state is PaymentFlowBlocked;
  }, 'initial device verdict');
  if (container.read(paymentFlowProvider) is PaymentFlowSuccess) {
    await container.read(paymentFlowProvider.notifier).repeatPayment();
    await pumpUntil(
      tester,
      () => container.read(paymentFlowProvider) is PaymentFlowReady,
      'repeat review',
    );
  }
  expect(container.read(paymentFlowProvider), isA<PaymentFlowReady>());
  return (container: container, security: security);
}

Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done,
  String stage, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final clock = Stopwatch()..start();
  while (!done()) {
    if (clock.elapsed > timeout) fail('Timed out waiting for $stage');
    // These are real on-device frames; platform work does not use a fake clock.
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump();
}

Future<void> tapPay(WidgetTester tester) => tester.tap(
  find
      .descendant(
        of: find.byType(PayActionBar),
        matching: find.byType(FilledButton),
      )
      .hitTestable(),
);
