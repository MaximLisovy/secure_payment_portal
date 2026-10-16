import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/app/brand/brand_providers.dart';

/// The host's request, independent of the payment screen's brand layout.
final selectedPaymentIdProvider = NotifierProvider<SelectedPaymentId, String>(
  SelectedPaymentId.new,
);

class SelectedPaymentId extends Notifier<String> {
  String? _explicitPaymentId;

  @override
  String build() {
    final brand = ref.watch(activeBrandProvider);
    final registry = ref.watch(brandRegistryProvider);
    return _explicitPaymentId ?? registry.demoPaymentIdFor(brand.id);
  }

  /// Navigation or a host can supply any bill without changing the brand.
  void select(String paymentId) {
    if (paymentId.trim().isEmpty) {
      throw ArgumentError.value(paymentId, 'paymentId', 'must not be empty');
    }
    _explicitPaymentId = paymentId;
    state = paymentId;
  }

  void useDemoDefault() {
    _explicitPaymentId = null;
    ref.invalidateSelf();
  }
}
