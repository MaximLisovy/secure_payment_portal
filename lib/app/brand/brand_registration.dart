import 'package:secure_payment_portal/brands/brand_config.dart';

/// App launch configuration. A demo bill is not part of a brand's design.
final class BrandRegistration {
  const BrandRegistration({required this.brand, required this.demoPaymentId});

  final BrandConfig brand;
  final String demoPaymentId;
}
