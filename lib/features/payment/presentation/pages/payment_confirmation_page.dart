import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/payment_body.dart';
import 'package:secure_payment_portal/features/security/security.dart';

/// The payment confirmation screen. The host passes the title and any app bar
/// actions: the feature does not know which brand it runs in.
///
/// The whole screen is a [SecureScreen], so the window is protected from the
/// first frame until the page is gone.
class PaymentConfirmationPage extends ConsumerStatefulWidget {
  const PaymentConfirmationPage({
    required this.title,
    this.appBarActions = const [],
    super.key,
  });

  final String title;
  final List<Widget> appBarActions;

  @override
  ConsumerState<PaymentConfirmationPage> createState() =>
      _PaymentConfirmationPageState();
}

class _PaymentConfirmationPageState
    extends ConsumerState<PaymentConfirmationPage> {
  @override
  void initState() {
    super.initState();
    // The flow is screen-scoped and starts when the bill arrives. Keep it alive
    // for the page's lifetime: while the bill loads, no widget watches it yet.
    ref.listenManual(paymentFlowProvider, (_, _) {});
    ref.listenManual(paymentDetailsProvider, (_, next) {
      final details = next.value;
      if (next.hasValue && !next.isLoading && details != null) {
        ref.read(paymentFlowProvider.notifier).begin(details);
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: widget.appBarActions,
        ),
        body: const SafeArea(top: false, child: PaymentBody()),
      ),
    );
  }
}
