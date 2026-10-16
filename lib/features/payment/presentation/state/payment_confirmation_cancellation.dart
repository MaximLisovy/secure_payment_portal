import 'package:secure_payment_portal/core/async/cancellation.dart';

/// A command belongs to the request it was created for, even before Riverpod
/// rebuilds dependents or replacement details finish loading.
final class PaymentConfirmationCancellation implements CancellationSignal {
  PaymentConfirmationCancellation(this._paymentId, this._currentPaymentId);

  final String _paymentId;
  final String Function() _currentPaymentId;
  final CancellationSource _source = CancellationSource();

  @override
  bool get isCancelled =>
      _source.isCancelled || _currentPaymentId() != _paymentId;

  void cancel() => _source.cancel();
}
