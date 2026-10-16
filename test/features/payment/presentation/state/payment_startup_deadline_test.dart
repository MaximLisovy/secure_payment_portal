import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/core/logging/logger.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/channel_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:secure_payment_portal/features/payment/di/payment_data_source_providers.dart';
import 'package:secure_payment_portal/features/payment/di/payment_providers.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_repository.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_notifier.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';

import '../../../../helpers/fake_async_helpers.dart';
import '../../../../helpers/pump_app.dart';
import '../../helpers/flow_harness.dart';
import '../../helpers/native_payment_simulator.dart';
import '../../helpers/payment_ui_harness.dart';

class _Payments extends Mock implements PaymentRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'silent activation blocks at the deadline and retry opens a fresh stream',
    () {
      fakeAsync((async) {
        final first = StreamController<PaymentProgress>();
        final second = StreamController<PaymentProgress>();
        var opens = 0;
        final repository = _Payments();
        when(
          repository.watchProgress,
        ).thenAnswer((_) => ++opens == 1 ? first.stream : second.stream);
        final h = FlowHarness.create(
          overrides: [paymentRepositoryProvider.overrideWithValue(repository)],
        );
        h.protectWindow(async);
        h.begin(async);
        async.elapse(
          paymentStartupFirstEventDeadline - const Duration(milliseconds: 1),
        );
        expect(h.flow.state, const PaymentFlowIdle());
        async.elapse(const Duration(milliseconds: 1));
        expect(h.flow.state, const PaymentFlowUnavailable());
        unawaited(h.flow.confirm());
        async.flushMicrotasks();
        verifyNever(() => repository.preparePayment());
        unawaited(h.flow.retry());
        async.flushMicrotasks();
        expect(first.hasListener, isFalse);
        expect(opens, 2);
        second.add(const PaymentIdle());
        async.flushMicrotasks();
        expect(h.flow.state, const PaymentFlowReady());
        async.elapse(paymentStartupFirstEventDeadline);
        expect(h.flow.state, const PaymentFlowReady());
        h.container.dispose();
        unawaited(first.close());
        unawaited(second.close());
        async.flushMicrotasks();
        expectNoPendingTimers(async);
      });
    },
  );

  test(
    'a late first replay restores a running attempt after startup blocked',
    () {
      fakeAsync((async) {
        final progress = StreamController<PaymentProgress>();
        final repository = _Payments();
        when(repository.watchProgress).thenAnswer((_) => progress.stream);
        final h = FlowHarness.create(
          overrides: [paymentRepositoryProvider.overrideWithValue(repository)],
        );
        h.begin(async);
        async.elapse(paymentStartupFirstEventDeadline);
        expect(h.flow.state, const PaymentFlowUnavailable());
        progress.add(
          const PaymentInProgress('bill-1', 40, attemptId: 'native-attempt'),
        );
        async.flushMicrotasks();
        expect(h.flow.state, const PaymentFlowProcessing(percent: 40));
        h.container.dispose();
        unawaited(progress.close());
        async.flushMicrotasks();
        expectNoPendingTimers(async);
      });
    },
  );

  test('disposing a silent startup cancels its deadline and subscription', () {
    fakeAsync((async) {
      final progress = StreamController<PaymentProgress>();
      final repository = _Payments();
      when(repository.watchProgress).thenAnswer((_) => progress.stream);
      final h = FlowHarness.create(
        overrides: [paymentRepositoryProvider.overrideWithValue(repository)],
      );
      h.begin(async);
      h.container.dispose();
      async.flushMicrotasks();
      expect(progress.hasListener, isFalse);
      unawaited(progress.close());
      async.flushMicrotasks();
      expectNoPendingTimers(async);
    });
  });

  test('a first stream error blocks without enabling confirmation', () {
    fakeAsync((async) {
      final progress = StreamController<PaymentProgress>();
      final repository = _Payments();
      when(repository.watchProgress).thenAnswer((_) => progress.stream);
      final h = FlowHarness.create(
        overrides: [paymentRepositoryProvider.overrideWithValue(repository)],
      );
      h.begin(async);
      progress.addError(StateError('unreadable first event'));
      async.flushMicrotasks();
      expect(h.flow.state, const PaymentFlowUnavailable());
      h.container.dispose();
      unawaited(progress.close());
      async.flushMicrotasks();
      expectNoPendingTimers(async);
    });
  });

  testWidgets(
    'missing native plugin reports FlutterError but flow blocks by deadline',
    (tester) async {
      NativePaymentSimulator.uninstall();
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      final source = ChannelPaymentPlatformDataSource(
        methods: paymentMethodChannel,
        progressEvents: paymentProgressChannel,
        logger: const SilentLogger(),
      );
      try {
        final container = await tester.pumpApp(
          const PaymentConfirmationPage(title: 'Test'),
          brand: retailBrand,
          overrides: [
            ...instantBackend(),
            paymentRepositoryProvider.overrideWith(
              (ref) => PaymentRepositoryImpl(
                remote: ref.read(paymentRemoteDataSourceProvider),
                platform: source,
                logger: const SilentLogger(),
              ),
            ),
          ],
        );
        await tester.pump();
        await tester.pump();
        await tester.runAsync(() => pumpEventQueue());
        await tester.pump(paymentStartupFirstEventDeadline);
        expect(
          container.read(paymentFlowProvider),
          const PaymentFlowUnavailable(),
        );
        expect(reported, isNotEmpty);
        await tester.unmountApp();
        await source.dispose();
        await tester.pump();
      } finally {
        FlutterError.onError = previous;
      }
    },
  );
}
