import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/brands/utility/utility_brand.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_style.dart';

void main() {
  final motion = retailBrand.tokens.motion;

  group('period', () {
    test('is four times the slow duration when that is in range', () {
      expect(
        ScanStyle.periodFor(
          motion.copyWith(slow: const Duration(milliseconds: 600)),
        ),
        const Duration(milliseconds: 2400),
      );
    });

    test('is held up to the minimum for a crisp brand', () {
      expect(
        ScanStyle.periodFor(
          motion.copyWith(slow: const Duration(milliseconds: 240)),
        ),
        ScanStyle.minPeriod,
      );
    });

    test('is held down to the maximum for a slow brand', () {
      expect(
        ScanStyle.periodFor(motion.copyWith(slow: const Duration(seconds: 2))),
        ScanStyle.maxPeriod,
      );
    });

    test('keeps the documented bounds', () {
      expect(ScanStyle.minPeriod, const Duration(milliseconds: 1600));
      expect(ScanStyle.maxPeriod, const Duration(milliseconds: 3000));
    });
  });

  group('from the tokens', () {
    test('reads the glow, the track, the core and the curve', () {
      final colors = retailBrand.tokens.colors;
      final style = ScanStyle.from(colors, motion);
      expect(style.glow, colors.scanGlow);
      expect(style.track, colors.outlineSubtle);
      expect(style.core, colors.brandOnSurface);
      expect(style.pulseCurve, motion.standard);
    });

    test('is equal for equal tokens and differs between the brands', () {
      final retail = ScanStyle.from(
        retailBrand.tokens.colors,
        retailBrand.tokens.motion,
      );
      expect(
        retail,
        ScanStyle.from(retailBrand.tokens.colors, retailBrand.tokens.motion),
      );
      expect(
        retail,
        isNot(
          ScanStyle.from(
            utilityBrand.tokens.colors,
            utilityBrand.tokens.motion,
          ),
        ),
      );
    });

    test('gives Retail a fluid scan and Utility a crisp one', () {
      final retail = ScanStyle.from(
        retailBrand.tokens.colors,
        retailBrand.tokens.motion,
      );
      final utility = ScanStyle.from(
        utilityBrand.tokens.colors,
        utilityBrand.tokens.motion,
      );
      expect(retail.period, const Duration(milliseconds: 2400));
      expect(utility.period, ScanStyle.minPeriod);
      expect(retail.pulseCurve, Curves.easeInOutCubic);
      expect(utility.pulseCurve, Curves.easeOut);
    });
  });

  test('every registered brand gets a usable scan', () {
    for (final brand in BrandRegistry.standard.all) {
      final style = ScanStyle.from(brand.tokens.colors, brand.tokens.motion);
      expect(
        style.period >= ScanStyle.minPeriod &&
            style.period <= ScanStyle.maxPeriod,
        isTrue,
        reason: brand.id,
      );
      expect(style.glow.a, 1.0, reason: '${brand.id}: the glow is opaque');
      expect(style.pulseCurve.transform(0), 0, reason: brand.id);
      expect(style.pulseCurve.transform(1), 1, reason: brand.id);
    }
  });
}
