import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/token_fixtures.dart';

void main() {
  group('BrandDensity', () {
    test('copyWith with no arguments returns an equal instance', () {
      expect(sampleDensityA.copyWith(), sampleDensityA);
    });

    test('copyWith replaces only the given fields', () {
      final copy = sampleDensityA.copyWith(rowHeight: 123);

      expect(copy.rowHeight, 123);
      expect(copy.controlHeight, sampleDensityA.controlHeight);
      expect(copy.visualDensity, sampleDensityA.visualDensity);
      expect(copy.spaceMd, sampleDensityA.spaceMd);
    });

    test('lerp with null returns this', () {
      expect(sampleDensityA.lerp(null, 0.5), same(sampleDensityA));
    });

    test('lerp(0) equals this and lerp(1) equals other', () {
      expect(sampleDensityA.lerp(sampleDensityB, 0), sampleDensityA);
      expect(sampleDensityA.lerp(sampleDensityB, 1), sampleDensityB);
    });

    test('lerp(0.5) interpolates numbers and the visual density', () {
      final mid = sampleDensityA.lerp(sampleDensityB, 0.5);

      expect(mid.spaceXs, 4);
      expect(mid.spaceMd, 16);
      expect(mid.rowHeight, 60);
      expect(mid.controlHeight, 48);
      expect(
        mid.visualDensity,
        VisualDensity.lerp(VisualDensity.compact, VisualDensity.standard, 0.5),
      );
    });
  });
}
