import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/token_fixtures.dart';

void main() {
  group('BrandMotion', () {
    test('copyWith with no arguments returns an equal instance', () {
      expect(sampleMotionA.copyWith(), sampleMotionA);
    });

    test('copyWith replaces only the given fields', () {
      const fast = Duration(milliseconds: 1);

      final copy = sampleMotionA.copyWith(fast: fast);

      expect(copy.fast, fast);
      expect(copy.medium, sampleMotionA.medium);
      expect(copy.standard, sampleMotionA.standard);
      expect(copy.pageTransitions, sampleMotionA.pageTransitions);
    });

    test('lerp with null returns this', () {
      expect(sampleMotionA.lerp(null, 0.5), same(sampleMotionA));
    });

    test('lerp(0) equals this and lerp(1) equals other', () {
      expect(sampleMotionA.lerp(sampleMotionB, 0), sampleMotionA);
      expect(sampleMotionA.lerp(sampleMotionB, 1), sampleMotionB);
    });

    test('lerp(0.5) interpolates durations', () {
      final mid = sampleMotionA.lerp(sampleMotionB, 0.5);

      expect(mid.fast, const Duration(milliseconds: 200));
      expect(mid.medium, const Duration(milliseconds: 400));
      expect(mid.slow, const Duration(milliseconds: 800));
    });

    test('curves and page transitions switch at t = 0.5', () {
      final before = sampleMotionA.lerp(sampleMotionB, 0.49);
      final after = sampleMotionA.lerp(sampleMotionB, 0.5);

      expect(before.standard, sampleMotionA.standard);
      expect(before.emphasized, sampleMotionA.emphasized);
      expect(before.pageTransitions, sampleMotionA.pageTransitions);
      expect(after.standard, sampleMotionB.standard);
      expect(after.emphasized, sampleMotionB.emphasized);
      expect(after.pageTransitions, sampleMotionB.pageTransitions);
    });
  });
}
