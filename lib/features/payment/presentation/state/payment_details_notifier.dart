import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/error/failure_exception.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/features/payment/di/payment_providers.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';

/// Loads the bill once. A load is an idempotent read, so reloading (the retry
/// button, a changed brand) is safe.
///
/// It watches the screen config, so a different bill id loads a different bill.
/// A failure is held as an `AsyncError` carrying the typed `Failure`.
class PaymentDetailsNotifier extends AsyncNotifier<PaymentDetails> {
  @override
  Future<PaymentDetails> build() async {
    final paymentId = ref.watch(paymentScreenConfigProvider).paymentId;
    final result = await ref
        .watch(paymentRepositoryProvider)
        .getPaymentDetails(paymentId);
    return switch (result) {
      Success<PaymentDetails>(:final value) => value,
      Err<PaymentDetails>(:final failure) => throw FailureException(failure),
    };
  }
}
