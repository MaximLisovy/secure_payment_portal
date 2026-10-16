import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/core/logging/logger.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/channel_payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:secure_payment_portal/features/payment/domain/confirm_payment.dart';
import 'package:secure_payment_portal/features/security/security_domain.dart';

import '../../../../helpers/fake_bills.dart';
import '../../helpers/native_payment_simulator.dart';
import '../../helpers/payment_fixtures.dart';

class _Security implements SecurityStatusRepository {
  SecurityStatus status = const SecurityStatus(
    root: RootClear(),
    screenRecording: Detection.notDetected,
    windowProtection: WindowProtection.active,
  );
  int reads = 0;
  @override
  Future<Result<SecurityStatus>> getStatus() async {
    reads++;
    return Success(status);
  }

  @override
  Stream<SecurityStatus> watchStatus() => Stream.value(status);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'recording started during the real channel prompt prevents native start',
    () {
      fakeAsync((async) {
        final native = NativePaymentSimulator()
          ..permissionDelay = const Duration(seconds: 40);
        final security = _Security();
        final source = ChannelPaymentPlatformDataSource(
          methods: paymentMethodChannel,
          progressEvents: paymentProgressChannel,
          logger: const SilentLogger(),
        );
        final useCase = ConfirmPayment(
          security: security,
          payments: PaymentRepositoryImpl(
            remote: FakePaymentRemoteDataSource(bills: FakeBills.all),
            platform: source,
            logger: const SilentLogger(),
          ),
          policy: const SecurityPolicy(),
        );
        Result<void>? result;
        unawaited(
          useCase(
            sampleDetails,
            attemptId: 'attempt-1',
          ).then((value) => result = value),
        );
        async.elapse(const Duration(seconds: 39));
        expect(security.reads, 0);
        expect(native.calls, [PaymentChannel.requestNotificationPermission]);
        security.status = security.status.copyWith(
          screenRecording: Detection.detected,
        );
        async.elapse(const Duration(seconds: 2));
        expect(security.reads, 1);
        expect(
          result?.failureOrNull,
          SecurityBlockedFailure(SecurityBlockReason.screenRecording),
        );
        expect(native.calls, isNot(contains(PaymentChannel.startPayment)));
        unawaited(source.dispose());
        NativePaymentSimulator.uninstall();
        async.flushMicrotasks();
      });
    },
  );
}
