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
