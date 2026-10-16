import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_payment_portal/core/async/cancellation.dart';
import 'package:secure_payment_portal/core/domain/currency.dart';
import 'package:secure_payment_portal/core/domain/money.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/features/payment/domain/confirm_payment.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_failures.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_repository.dart';
import 'package:secure_payment_portal/features/security/security_domain.dart';

import '../../../helpers/fake_async_helpers.dart';
import '../../security/helpers/security_fixtures.dart';
import '../helpers/payment_fixtures.dart';

class _MockSecurity extends Mock implements SecurityStatusRepository {}

class _MockPayments extends Mock implements PaymentRepository {}

const _recording = SecurityStatus(
  root: RootClear(),
  screenRecording: Detection.detected,
  windowProtection: WindowProtection.active,
);

void main() {
  late _MockSecurity security;
  late _MockPayments payments;

  setUpAll(() => registerFallbackValue(sampleDetails));

  setUp(() {
    security = _MockSecurity();
    payments = _MockPayments();
    when(() => payments.preparePayment()).thenAnswer((_) async => Success.unit);
    when(
      () => payments.startPayment(any(), attemptId: 'attempt-1'),
    ).thenAnswer((_) async => Success.unit);
  });

  void deviceReads(SecurityStatus status) => when(
    () => security.getStatus(),
  ).thenAnswer((_) async => Success<SecurityStatus>(status));

  ConfirmPayment confirm([SecurityPolicy policy = const SecurityPolicy()]) =>
      ConfirmPayment(security: security, payments: payments, policy: policy);

  group('confirmation cancellation', () {
    test('a cancelled command never prepares or starts payment', () {
      fakeAsync((async) {
        final cancellation = CancellationSource()..cancel();
        final result = FutureProbe(
          confirm()(
            sampleDetails,
            attemptId: 'attempt-1',
            cancellation: cancellation,
          ),
        );
        async.flushMicrotasks();
        expect(
          result.value,
          const Err<void>(PaymentConfirmationObsoleteFailure()),
        );
        verifyNever(() => payments.preparePayment());
        verifyNever(() => security.getStatus());
        verifyNever(() => payments.startPayment(any(), attemptId: 'attempt-1'));
      });
    });

    for (final stage in ['preparation', 'security']) {
      test('cancellation during $stage prevents native acceptance', () {
        fakeAsync((async) {
          final preparation = Completer<Result<void>>();
          final status = Completer<Result<SecurityStatus>>();
          when(
            () => payments.preparePayment(),
          ).thenAnswer((_) => preparation.future);
          when(() => security.getStatus()).thenAnswer((_) => status.future);
          final cancellation = CancellationSource();
          final result = FutureProbe(
            confirm()(
              sampleDetails,
              attemptId: 'attempt-1',
              cancellation: cancellation,
            ),
          );
          async.flushMicrotasks();
          if (stage == 'security') {
            preparation.complete(Success.unit);
            async.flushMicrotasks();
          }
          cancellation.cancel();
          if (stage == 'preparation') preparation.complete(Success.unit);
          status.complete(const Success(cleanStatus));
          async.flushMicrotasks();
          expect(
            result.value,
            const Err<void>(PaymentConfirmationObsoleteFailure()),
          );
          verifyNever(
            () => payments.startPayment(any(), attemptId: 'attempt-1'),
          );
          if (stage == 'preparation') verifyNever(() => security.getStatus());
          expectNoPendingTimers(async);
        });
      });
    }

    test(
      'cancellation after acceptance does not cancel the running payment',
      () {
        fakeAsync((async) {
          deviceReads(cleanStatus);
          final cancellation = CancellationSource();
          final result = FutureProbe(
            confirm()(
              sampleDetails,
              attemptId: 'attempt-1',
              cancellation: cancellation,
            ),
          );
          async.flushMicrotasks();
          expect(result.value, Success.unit);
          cancellation.cancel();
          verifyNever(() => payments.cancelPayment(attemptId: 'attempt-1'));
          expectNoPendingTimers(async);
        });
      },
    );
  });

  group('when the device is fine', () {
    test('checks the device first, then starts processing', () async {
      deviceReads(cleanStatus);

      final result = await confirm()(sampleDetails, attemptId: 'attempt-1');

      expect(result, Success.unit);
      verifyInOrder([
        () => security.getStatus(),
        () => payments.startPayment(sampleDetails, attemptId: 'attempt-1'),
      ]);
    });

    test('re-reads the status on every confirm, never a cached one', () async {
      deviceReads(cleanStatus);
      final useCase = confirm();

      await useCase(sampleDetails, attemptId: 'attempt-1');
      await useCase(sampleDetails, attemptId: 'attempt-1');

      verify(() => security.getStatus()).called(2);
    });

    test(
      'only reads the status once; it does not subscribe to a stream',
      () async {
        deviceReads(cleanStatus);

        await confirm()(sampleDetails, attemptId: 'attempt-1');

        verifyNever(() => security.watchStatus());
      },
    );

    test('weak root signals alone do not stop a payment by default', () async {
      deviceReads(
        SecurityStatus(
          root: weakRoot,
          screenRecording: Detection.notDetected,
          windowProtection: WindowProtection.active,
        ),
      );

      expect(
        await confirm()(sampleDetails, attemptId: 'attempt-1'),
        Success.unit,
      );
    });

    test(
      'an unverifiable recording state does not stop it by default',
      () async {
        deviceReads(
          const SecurityStatus(
            root: RootClear(),
            screenRecording: Detection.unknown,
            windowProtection: WindowProtection.active,
          ),
        );

        expect(
          await confirm()(sampleDetails, attemptId: 'attempt-1'),
          Success.unit,
        );
      },
    );
  });

  group('when the policy blocks', () {
    final blocked = <(String, SecurityStatus, SecurityBlockReason)>[
      (
        'a strong root signal',
        SecurityStatus(
          root: strongRoot,
          screenRecording: Detection.notDetected,
          windowProtection: WindowProtection.active,
        ),
        SecurityBlockReason.rootDetected,
      ),
      (
        'a recording in progress',
        _recording,
        SecurityBlockReason.screenRecording,
      ),
      (
        'a root that cannot be verified',
        const SecurityStatus(
          root: RootUnknown(),
          screenRecording: Detection.notDetected,
          windowProtection: WindowProtection.active,
        ),
        SecurityBlockReason.rootUnverifiable,
      ),
    ];
    for (final (name, status, reason) in blocked) {
      test('$name fails with $reason and never starts processing', () async {
        deviceReads(status);

        final result = await confirm()(sampleDetails, attemptId: 'attempt-1');

        expect(result, Err<void>(SecurityBlockedFailure(reason)));
        verifyNever(() => payments.startPayment(any(), attemptId: 'attempt-1'));
      });
    }

    test(
      'a status that cannot be read is treated as unknown, fail-closed',
      () async {
        when(
          () => security.getStatus(),
        ).thenAnswer((_) async => const Err<SecurityStatus>(NetworkFailure()));

        final result = await confirm()(sampleDetails, attemptId: 'attempt-1');

        expect(
          result,
          Err<void>(
            SecurityBlockedFailure(SecurityBlockReason.rootUnverifiable),
          ),
        );
        verifyNever(() => payments.startPayment(any(), attemptId: 'attempt-1'));
      },
    );

    test('the policy, not the use case, decides what unknown means', () async {
      when(
        () => security.getStatus(),
      ).thenAnswer((_) async => const Err<SecurityStatus>(NetworkFailure()));

      final result = await confirm(
        const SecurityPolicy(
          blockOnUnknownRoot: false,
          blockOnUnprotectedWindow: false,
        ),
      )(sampleDetails, attemptId: 'attempt-1');

      expect(result, Success.unit);
      verify(
        () => payments.startPayment(sampleDetails, attemptId: 'attempt-1'),
      ).called(1);
    });

    test(
      'a window that is not protected blocks, and never starts processing',
      () async {
        deviceReads(
          const SecurityStatus(
            root: RootClear(),
            screenRecording: Detection.notDetected,
            windowProtection: WindowProtection.inactive,
          ),
        );

        final result = await confirm()(sampleDetails, attemptId: 'attempt-1');

        expect(
          result,
          Err<void>(
            SecurityBlockedFailure(
              SecurityBlockReason.screenProtectionUnavailable,
            ),
          ),
        );
        verifyNever(() => payments.startPayment(any(), attemptId: 'attempt-1'));
      },
    );

    test('a stricter policy can block an unverifiable recording', () async {
      deviceReads(
        const SecurityStatus(
          root: RootClear(),
          screenRecording: Detection.unknown,
          windowProtection: WindowProtection.active,
        ),
      );

      final result = await confirm(
        const SecurityPolicy(blockOnUnknownRecording: true),
      )(sampleDetails, attemptId: 'attempt-1');

      expect(
        result,
        Err<void>(
          SecurityBlockedFailure(SecurityBlockReason.recordingUnverifiable),
        ),
      );
    });
  });

  group('when there is nothing valid to pay', () {
    final invalid = <(String, PaymentDetails)>[
      ('no lines', detailsWith(const [])),
      (
        'a zero total',
        detailsWith([usdItem(500), usdItem(-500, LineItemKind.discount)]),
      ),
      (
        'a negative total',
        detailsWith([usdItem(100), usdItem(-900, LineItemKind.discount)]),
      ),
      (
        'a line in another currency',
        detailsWith([
          usdItem(1000),
          const BillLineItem(
            label: 'euro line',
            amount: Money.minor(1000, Currency.eur),
            kind: LineItemKind.charge,
          ),
        ]),
      ),
    ];
    for (final (name, details) in invalid) {
      test(
        '$name fails with InvalidPaymentFailure and touches nothing',
        () async {
          final result = await confirm()(details, attemptId: 'attempt-1');

          expect(result, const Err<void>(InvalidPaymentFailure()));
          verifyNever(() => security.getStatus());
          verifyNever(
            () => payments.startPayment(any(), attemptId: 'attempt-1'),
          );
        },
      );
    }
  });

  group('when starting fails', () {
    test(
      'a second confirm while one runs reports PaymentInProgressFailure',
      () async {
        deviceReads(cleanStatus);
        when(
          () => payments.startPayment(any(), attemptId: 'attempt-1'),
        ).thenAnswer((_) async => const Err<void>(PaymentInProgressFailure()));

        expect(
          await confirm()(sampleDetails, attemptId: 'attempt-1'),
          const Err<void>(PaymentInProgressFailure()),
        );
      },
    );

    test(
      'any other failure from the repository is passed through unchanged',
      () async {
        deviceReads(cleanStatus);
        when(
          () => payments.startPayment(any(), attemptId: 'attempt-1'),
        ).thenAnswer(
          (_) async => const Err<void>(PlatformFailure('START_NOT_ALLOWED')),
        );

        expect(
          await confirm()(sampleDetails, attemptId: 'attempt-1'),
          const Err<void>(PlatformFailure('START_NOT_ALLOWED')),
        );
      },
    );
  });
}
