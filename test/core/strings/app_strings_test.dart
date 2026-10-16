import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_failures.dart';
import 'package:secure_payment_portal/features/security/security_domain.dart';

void main() {
  group('AppStrings.message', () {
    final fallback = AppStrings.message('no.such.key');

    // Every failure a screen can show. A new Failure type with a key nobody
    // wrote text for would read as the generic fallback: add it here.
    final failures = <Failure>[
      const NetworkFailure(),
      const NotFoundFailure(),
      const InvalidDataFailure(),
      const PlatformFailure('anything'),
      const UnsupportedFailure(),
      const UnexpectedFailure(),
      const PaymentDeclinedFailure(),
      const PaymentInProgressFailure(),
      const PaymentStartNotAllowedFailure(),
      const InvalidPaymentFailure(),
      const PaymentProcessingFailure(),
      const PaymentConfirmationObsoleteFailure(),
    ];

    for (final failure in failures) {
      test('${failure.messageKey} has its own text', () {
        final text = AppStrings.message(failure.messageKey);

        expect(text, isNotEmpty);
        expect(text, isNot(fallback));
      });
    }

    for (final reason in SecurityBlockReason.values) {
      test('${reason.messageKey} has its own text', () {
        final text = AppStrings.message(reason.messageKey);

        expect(text, isNotEmpty);
        expect(text, isNot(fallback));
      });
    }

    test('an unknown key reads as a generic problem, never as the key', () {
      expect(fallback, isNot(contains('no.such.key')));
      expect(fallback, isNotEmpty);
    });

    test('a failure that carries a block reason shows the reason\'s text', () {
      final failure = SecurityBlockedFailure(SecurityBlockReason.rootDetected);

      expect(
        AppStrings.message(failure.messageKey),
        AppStrings.message(SecurityBlockReason.rootDetected.messageKey),
      );
    });
  });

  group('AppStrings.demoSeconds', () {
    test('writes whole seconds without a fraction', () {
      expect(AppStrings.demoSeconds(const Duration(seconds: 5)), '5 s');
      expect(AppStrings.demoSeconds(Duration.zero), '0 s');
    });

    test('keeps a fraction of a second', () {
      expect(
        AppStrings.demoSeconds(const Duration(milliseconds: 1500)),
        '1.5 s',
      );
    });
  });

  group('AppStrings.blockedHint', () {
    test('only reasons that lift by themselves have a hint', () {
      for (final reason in SecurityBlockReason.values) {
        final hint = AppStrings.blockedHint(reason.messageKey);
        if (hint != null) {
          expect(reason.isRecoverable, isTrue, reason: reason.name);
        }
      }
      expect(
        AppStrings.blockedHint(SecurityBlockReason.screenRecording.messageKey),
        isNotNull,
      );
    });
  });
}
