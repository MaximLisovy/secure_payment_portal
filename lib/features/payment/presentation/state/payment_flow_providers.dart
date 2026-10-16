import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_details_notifier.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_notifier.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';

/// Screen-scoped: gone when the page is.
final paymentDetailsProvider =
    AsyncNotifierProvider.autoDispose<PaymentDetailsNotifier, PaymentDetails>(
      PaymentDetailsNotifier.new,
    );

/// The bill, for widgets that are only built once it has loaded. Reading it
/// before then is a bug, so it throws rather than returning a placeholder.
final loadedPaymentDetailsProvider = Provider.autoDispose<PaymentDetails>(
  (ref) => ref.watch(paymentDetailsProvider).requireValue,
);

final paymentFlowProvider =
    NotifierProvider.autoDispose<PaymentFlowNotifier, PaymentFlowState>(
      PaymentFlowNotifier.new,
    );

/// Whether a payment is being started or processed. For a host that must not
/// swap a source from under it: a payment belongs to the source that started it,
/// and a new source would not know about it.
final paymentInProgressProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(
    paymentFlowProvider.select(
      (state) =>
          state is PaymentFlowConfirming ||
          state is PaymentFlowProcessing ||
          state is PaymentFlowCheckingStatus,
    ),
  ),
);
