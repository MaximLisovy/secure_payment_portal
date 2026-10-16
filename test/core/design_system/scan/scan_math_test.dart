import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_math.dart';

/// Phases across one period, avoiding the exact wrap so a rounding error cannot
/// put a sample on the other side of it.
final _phases = [for (var k = 0; k < 400; k++) (k + 0.5) / 400];

void main() {
  test('frac is the fractional part, also for negative numbers', () {
    expect(ScanMath.frac(2.5), closeTo(0.5, 1e-12));
    expect(ScanMath.frac(-0.25), closeTo(0.75, 1e-12));
    expect(ScanMath.frac(-3), 0);
    expect(ScanMath.frac(0), 0);
  });

  group('periodicity', () {
    test('the sweep turns by exactly one revolution per period', () {
      for (final t in _phases) {
        expect(
          ScanMath.sweepAngle(t + 1) - ScanMath.sweepAngle(t),
          closeTo(2 * math.pi, 1e-12),
        );
      }
    });

    test('every pulse quantity repeats after one period', () {
      for (final t in _phases) {
        for (var i = 0; i < ScanMath.pulseCount; i++) {
          final now = ScanMath.pulseProgress(t, i);
          final later = ScanMath.pulseProgress(t + 1, i);
          expect(later, closeTo(now, 1e-9));
          expect(
            ScanMath.pulseEnvelope(later),
            closeTo(ScanMath.pulseEnvelope(now), 1e-9),
          );
          expect(
            ScanMath.pulseStrokeScale(later),
            closeTo(ScanMath.pulseStrokeScale(now), 1e-9),
          );
        }
      }
    });

    test('a pulse is invisible on both sides of the wrap', () {
      expect(ScanMath.pulseEnvelope(0), 0);
      expect(ScanMath.pulseEnvelope(1 - 1e-9), closeTo(0, 1e-9));
    });

    test('the picture is continuous across the loop', () {
      // Just before the wrap and just after it, every drawn quantity matches.
      const epsilon = 1e-9;
      expect(
        ScanMath.sweepAngle(1 - epsilon) - 2 * math.pi,
        closeTo(ScanMath.sweepAngle(0), 1e-6),
      );
      for (var i = 0; i < ScanMath.pulseCount; i++) {
        expect(
          ScanMath.pulseEnvelope(ScanMath.pulseProgress(1 - epsilon, i)),
          closeTo(ScanMath.pulseEnvelope(ScanMath.pulseProgress(0, i)), 1e-6),
        );
      }
    });
  });

  group('pulses', () {
    test('are spaced a third of a period apart', () {
      for (final t in _phases) {
        for (var i = 1; i < ScanMath.pulseCount; i++) {
          final gap =
              ScanMath.frac(
                ScanMath.pulseProgress(t, i) - ScanMath.pulseProgress(t, 0),
              ) -
              i / ScanMath.pulseCount;
          expect(gap.abs() < 1e-9 || (gap.abs() - 1).abs() < 1e-9, isTrue);
        }
      }
    });

    test('stay within their ranges', () {
      for (var step = 0; step <= 1000; step++) {
        final p = step / 1000;
        expect(ScanMath.pulseEnvelope(p), inInclusiveRange(0, 1));
        expect(ScanMath.pulseStrokeScale(p), inInclusiveRange(0.5, 1));
        expect(
          ScanMath.pulseRadiusFraction(p, Curves.easeInOutCubic.transform),
          inInclusiveRange(0, 1),
        );
      }
    });

    test('are held inside the scan by a curve that overshoots', () {
      for (var step = 0; step <= 1000; step++) {
        final radius = ScanMath.pulseRadiusFraction(
          step / 1000,
          Curves.elasticOut.transform,
        );
        expect(radius, inInclusiveRange(0, 1));
      }
    });

    test('expand outwards for a curve that is monotonic', () {
      var last = -1.0;
      for (var step = 0; step <= 100; step++) {
        final radius = ScanMath.pulseRadiusFraction(
          step / 100,
          Curves.easeOut.transform,
        );
        expect(radius, greaterThanOrEqualTo(last));
        last = radius;
      }
    });

    test('never leave the scan empty', () {
      for (final t in _phases) {
        final brightest = [
          for (var i = 0; i < ScanMath.pulseCount; i++)
            ScanMath.pulseEnvelope(ScanMath.pulseProgress(t, i)),
        ].reduce(math.max);
        // The dimmest instant is about 0.4: one ring a third of the way out.
        expect(brightest, greaterThan(0.35));
      }
    });
  });

  group('sweep', () {
    test('is brightest at its edge and gone at the end of its tail', () {
      expect(ScanMath.sweepEnvelope(0), 1);
      expect(ScanMath.sweepEnvelope(ScanMath.sweepTail), 0);
      expect(ScanMath.sweepEnvelope(0.5), 0);
      expect(ScanMath.sweepEnvelope(-0.1), 0);
    });

    test('fades steadily along its tail', () {
      var last = 2.0;
      for (var step = 0; step < 100; step++) {
        final envelope = ScanMath.sweepEnvelope(
          step * ScanMath.sweepTail / 100,
        );
        expect(envelope, lessThanOrEqualTo(last));
        last = envelope;
      }
    });

    test('has a gradient that rises to the edge over increasing stops', () {
      final stops = ScanMath.sweepStops;
      final envelopes = ScanMath.sweepEnvelopes;
      expect(stops, hasLength(envelopes.length));
      expect(stops.first, 0);
      expect(stops.last, closeTo(1, 1e-12));
      expect(envelopes.last, 1);
      expect(envelopes.first, 0);
      for (var i = 1; i < stops.length; i++) {
        expect(stops[i], greaterThan(stops[i - 1]));
        expect(envelopes[i], greaterThanOrEqualTo(envelopes[i - 1]));
      }
    });
  });

  group('alpha levels', () {
    test('map the envelope onto whole steps', () {
      expect(ScanMath.alphaLevel(0), 0);
      expect(ScanMath.alphaLevel(1), ScanMath.alphaLevels);
      expect(ScanMath.alphaLevel(0.5), ScanMath.alphaLevels ~/ 2);
    });

    test('never leave the range', () {
      expect(ScanMath.alphaLevel(-3), 0);
      expect(ScanMath.alphaLevel(7), ScanMath.alphaLevels);
    });
  });

  test('the rest phase shows a wedge and rings at different radii', () {
    final radii = {
      for (var i = 0; i < ScanMath.pulseCount; i++)
        ScanMath.pulseProgress(ScanMath.restPhase, i),
    };
    expect(radii, hasLength(ScanMath.pulseCount));
    expect(ScanMath.restPhase, inInclusiveRange(0, 1));
  });
}
