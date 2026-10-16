import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';

/// Launch configuration and optional demo data, separate from visual design.
final class BrandRegistration {
  const BrandRegistration({
    required this.brand,
    required this.demoPaymentId,
    this.demoBills = const [],
  });

  final BrandConfig brand;
  final String demoPaymentId;
  final List<DemoBill> demoBills;
}
