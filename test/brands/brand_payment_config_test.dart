import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_bills.dart';

// Iterates the registry, so a newly registered brand is checked automatically.
void main() {
  for (final brand in BrandRegistry.standard.all) {
    group('payment config of ${brand.id}', () {
      test('declares at least one section', () {
        expect(brand.payment.sections, isNotEmpty);
      });

      test('names a bill the backend knows', () {
        // A typo here would only show up at runtime as "bill not found".
        expect(
          FakeBills.all.keys,
          contains(brand.payment.paymentId),
          reason: '${brand.id} points at ${brand.payment.paymentId}',
        );
      });
    });
  }

  test('different brands can show different bills', () {
    final ids = BrandRegistry.standard.all.map((b) => b.payment.paymentId);

    expect(ids.toSet(), hasLength(ids.length));
  });
}
