import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';

// Iterates the registry, so a newly registered brand is checked automatically.
void main() {
  for (final brand in BrandRegistry.standard.all) {
    group('payment config of ${brand.id}', () {
      test('declares at least one section', () {
        expect(brand.payment.sections, isNotEmpty);
      });
    });
  }
}
