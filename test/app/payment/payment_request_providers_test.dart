import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_providers.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/app/di/root_overrides.dart';
import 'package:secure_payment_portal/app/payment/payment_request_providers.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/features/payment/di/payment_providers.dart';

import '../../helpers/fake_bills.dart';

ProviderContainer _container() =>
    ProviderContainer.test(overrides: rootOverrides(initialBrand: retailBrand));

void main() {
  for (final brand in BrandRegistry.standard.all) {
    test('${brand.id} has an available app-owned demo request', () {
      final container = ProviderContainer.test(
        overrides: rootOverrides(initialBrand: brand),
      );
      expect(FakeBills.all, contains(container.read(paymentIdProvider)));
      expect(container.read(paymentScreenConfigProvider), brand.payment);
    });
  }

  test(
    'the default follows a brand switch until a host request is selected',
    () {
      final container = _container();
      expect(container.read(paymentIdProvider), FakeBills.retailOrderId);
      container.read(activeBrandProvider.notifier).select('utility');
      expect(container.read(paymentIdProvider), FakeBills.utilityBillId);
    },
  );

  test('explicit selection survives a brand switch and changes no layout', () {
    final container = _container();
    final layout = container.read(paymentScreenConfigProvider);
    container.read(selectedPaymentIdProvider.notifier).select('host-order-7');
    expect(container.read(paymentIdProvider), 'host-order-7');
    expect(container.read(paymentScreenConfigProvider), layout);

    container.read(activeBrandProvider.notifier).select('utility');
    expect(container.read(paymentIdProvider), 'host-order-7');
    expect(container.read(paymentScreenConfigProvider), isNot(layout));
  });

  test('returning to demo defaults uses the currently active brand', () {
    final container = _container();
    final selection = container.read(selectedPaymentIdProvider.notifier);
    selection.select('host-order-7');
    container.read(activeBrandProvider.notifier).select('utility');
    selection.useDemoDefault();
    expect(container.read(paymentIdProvider), FakeBills.utilityBillId);
  });

  test(
    'an empty request is rejected without replacing the current request',
    () {
      final container = _container();
      final selection = container.read(selectedPaymentIdProvider.notifier);
      final initial = container.read(paymentIdProvider);
      expect(() => selection.select('  '), throwsArgumentError);
      expect(container.read(paymentIdProvider), initial);
    },
  );

  test('an unregistered demo lookup fails loudly', () {
    expect(
      () => BrandRegistry.standard.demoPaymentIdFor('unknown'),
      throwsA(isA<BrandResolutionError>()),
    );
  });
}
