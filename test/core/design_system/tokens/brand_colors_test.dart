import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/token_fixtures.dart';

void main() {
  group('BrandColors', () {
    test('copyWith with no arguments returns an equal instance', () {
      expect(sampleColorsA.copyWith(), sampleColorsA);
    });

    test('copyWith replaces only the given fields', () {
      const accent = Color(0xFF123456);

      final copy = sampleColorsA.copyWith(brandAccent: accent);

      expect(copy.brandAccent, accent);
      expect(
        copy.copyWith(brandAccent: sampleColorsA.brandAccent),
        sampleColorsA,
      );
    });

    test('lerp with null returns this', () {
      expect(sampleColorsA.lerp(null, 0.5), same(sampleColorsA));
    });

    test('lerp(0) equals this and lerp(1) equals other', () {
      expect(sampleColorsA.lerp(sampleColorsB, 0), sampleColorsA);
      expect(sampleColorsA.lerp(sampleColorsB, 1), sampleColorsB);
    });

    test('lerp(0.5) is strictly between the endpoints', () {
      final mid = sampleColorsA.lerp(sampleColorsB, 0.5);

      expect(
        mid.brandPrimary,
        Color.lerp(sampleColorsA.brandPrimary, sampleColorsB.brandPrimary, 0.5),
      );
      expect(
        mid.brandOnSurface,
        Color.lerp(
          sampleColorsA.brandOnSurface,
          sampleColorsB.brandOnSurface,
          0.5,
        ),
      );
      expect(
        mid.outlineSubtle,
        Color.lerp(
          sampleColorsA.outlineSubtle,
          sampleColorsB.outlineSubtle,
          0.5,
        ),
      );
      expect(mid.brandPrimary, isNot(sampleColorsA.brandPrimary));
      expect(mid.brandPrimary, isNot(sampleColorsB.brandPrimary));
      expect(mid.brandGradient, isNot(sampleColorsA.brandGradient));
      expect(mid.brandGradient, isNot(sampleColorsB.brandGradient));
    });

    test('equality is by value', () {
      expect(
        sampleColorsA.copyWith(brandPrimary: const Color(0xFF111111)),
        isNot(sampleColorsA),
      );
    });
  });
}
