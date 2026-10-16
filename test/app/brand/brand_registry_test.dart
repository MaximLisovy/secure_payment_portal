import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/brands/utility/utility_brand.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';

import '../../helpers/token_fixtures.dart';

const _payment = PaymentScreenConfig(
  paymentId: 'bill-1',
  sections: [SummarySpec()],
);

const _alpha = BrandConfig(
  id: 'alpha',
  displayName: 'Alpha',
  tokens: sampleTokensA,
  payment: _payment,
);
const _beta = BrandConfig(
  id: 'beta',
  displayName: 'Beta',
  tokens: sampleTokensB,
  payment: _payment,
);

void main() {
  group('BrandRegistry.standard', () {
    const registry = BrandRegistry.standard;

    // At least, not exactly: adding a brand adds to this list and must not need
    // a test edited.
    test('registers retail and utility', () {
      expect(registry.all, containsAll([retailBrand, utilityBrand]));
    });

    test('has unique, non-empty ids and display names', () {
      final ids = registry.all.map((b) => b.id).toList();

      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, everyElement(isNotEmpty));
      expect(registry.all.map((b) => b.displayName), everyElement(isNotEmpty));
    });

    test('has its default brand registered', () {
      expect(registry.byId(registry.defaultBrandId), isNotNull);
    });

    test('resolves the build-time flavor, falling back outside release', () {
      // `flutter test` sets no flavor and is not a release build.
      expect(registry.resolve(), registry.byId(registry.defaultBrandId));
    });
  });

  group('BrandRegistry.byId', () {
    const registry = BrandRegistry([_alpha, _beta], defaultBrandId: 'alpha');

    test('returns the matching brand', () {
      expect(registry.byId('beta'), _beta);
    });

    test('returns null for an unknown id', () {
      expect(registry.byId('gamma'), isNull);
    });
  });

  group('BrandRegistry.resolve', () {
    const registry = BrandRegistry([_alpha, _beta], defaultBrandId: 'alpha');

    for (final strict in [false, true]) {
      test('returns the brand for a known flavor (strict: $strict)', () {
        expect(registry.resolve(flavor: 'beta', strict: strict), _beta);
      });

      test('throws for an unknown flavor (strict: $strict)', () {
        expect(
          () => registry.resolve(flavor: 'gamma', strict: strict),
          throwsA(
            isA<BrandResolutionError>().having(
              (e) => e.message,
              'message',
              allOf(contains('gamma'), contains('alpha | beta')),
            ),
          ),
        );
      });
    }

    test(
      'falls back to the default brand without a flavor when not strict',
      () {
        expect(registry.resolve(flavor: null, strict: false), _alpha);
      },
    );

    test('throws without a flavor when strict (release)', () {
      expect(
        () => registry.resolve(flavor: null, strict: true),
        throwsA(
          isA<BrandResolutionError>().having(
            (e) => e.message,
            'message',
            contains('--flavor'),
          ),
        ),
      );
    });

    test('throws when the default brand is not registered', () {
      const broken = BrandRegistry([_beta], defaultBrandId: 'alpha');

      expect(
        () => broken.resolve(flavor: null, strict: false),
        throwsA(isA<BrandResolutionError>()),
      );
    });
  });
}
