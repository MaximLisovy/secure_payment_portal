import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_providers.dart';
import 'package:secure_payment_portal/app/di/root_overrides.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/brands/utility/utility_brand.dart';
import 'package:secure_payment_portal/features/payment/di/payment_providers.dart';

void main() {
  group('rootOverrides', () {
    test('gives the payment feature the active brand\'s config', () {
      final container = ProviderContainer.test(
        overrides: rootOverrides(initialBrand: retailBrand),
      );

      expect(container.read(paymentScreenConfigProvider), retailBrand.payment);
    });

    test('follows a brand switch', () async {
      final container = ProviderContainer.test(
        overrides: rootOverrides(initialBrand: retailBrand),
      );
      container.listen(paymentScreenConfigProvider, (_, _) {});

      container.read(activeBrandProvider.notifier).select('utility');
      await container.pump();

      expect(container.read(paymentScreenConfigProvider), utilityBrand.payment);
    });

    test('the feature fails loudly if nobody overrides its config', () {
      final container = ProviderContainer.test();

      expect(
        () => container.read(paymentScreenConfigProvider),
        throwsA(anything),
      );
    });
  });
}
