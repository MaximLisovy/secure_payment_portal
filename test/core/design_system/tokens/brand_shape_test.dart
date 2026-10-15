import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/token_fixtures.dart';

void main() {
  group('BrandShape', () {
    test('copyWith with no arguments returns an equal instance', () {
      expect(sampleShapeA.copyWith(), sampleShapeA);
    });

    test('copyWith replaces only the given fields', () {
      final copy = sampleShapeA.copyWith(radiusMd: 99);

      expect(copy.radiusMd, 99);
      expect(copy.radiusSm, sampleShapeA.radiusSm);
      expect(copy.radiusLg, sampleShapeA.radiusLg);
      expect(copy.borderWidth, sampleShapeA.borderWidth);
      expect(copy.cardElevation, sampleShapeA.cardElevation);
    });

    test('lerp with null returns this', () {
      expect(sampleShapeA.lerp(null, 0.5), same(sampleShapeA));
    });

    test('lerp(0) equals this and lerp(1) equals other', () {
      expect(sampleShapeA.lerp(sampleShapeB, 0), sampleShapeA);
      expect(sampleShapeA.lerp(sampleShapeB, 1), sampleShapeB);
    });

    test('lerp(0.5) interpolates every number', () {
      final mid = sampleShapeA.lerp(sampleShapeB, 0.5);

      expect(mid.radiusSm, 5);
      expect(mid.radiusMd, 11);
      expect(mid.radiusLg, 22);
      expect(mid.borderWidth, 2);
      expect(mid.cardElevation, 4);
    });

    test('derived helpers follow the numbers', () {
      expect(sampleShapeB.borderRadiusMd, BorderRadius.circular(20));
      expect(sampleShapeB.borderSide(Colors.black), const BorderSide(width: 3));
    });
  });
}
