import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_math.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_palette.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_style.dart';
import 'package:secure_payment_portal/core/design_system/scan/security_scan_painter.dart';

import 'scan_fixtures.dart';

const _size = Size(78, 78);

SecurityScanPainter _painterAt(double t, {ScanStyle? style}) =>
    SecurityScanPainter(
      animation: parkedAt(t),
      style: style ?? retailScanStyle,
    );

void main() {
  group('shouldRepaint', () {
    test('is false for an equal style', () {
      final painter = _painterAt(0.2);
      expect(painter.shouldRepaint(_painterAt(0.7)), isFalse);
    });

    test('ignores the animation, which repaints by itself', () {
      final a = SecurityScanPainter(
        animation: parkedAt(0),
        style: retailScanStyle,
      );
      final b = SecurityScanPainter(
        animation: parkedAt(0.9),
        style: retailScanStyle,
      );
      expect(a.shouldRepaint(b), isFalse);
    });

    test('is true when the glow changes', () {
      final other = ScanStyle(
        glow: const Color(0xFF123456),
        track: retailScanStyle.track,
        core: retailScanStyle.core,
        period: retailScanStyle.period,
        pulseCurve: retailScanStyle.pulseCurve,
      );
      expect(_painterAt(0).shouldRepaint(_painterAt(0, style: other)), isTrue);
    });

    test('is true when the pulse curve changes', () {
      final other = ScanStyle(
        glow: retailScanStyle.glow,
        track: retailScanStyle.track,
        core: retailScanStyle.core,
        period: retailScanStyle.period,
        pulseCurve: Curves.linear,
      );
      expect(_painterAt(0).shouldRepaint(_painterAt(0, style: other)), isTrue);
    });
  });

  group('one frame', () {
    test('draws three pulses under a sweep with its edge', () {
      final calls = recordPaint(_painterAt(ScanMath.restPhase), _size);
      // Two strokes per pulse (glow, then line) and the filled sweep.
      expect(callsTo(calls, #drawCircle), hasLength(7));
      expect(callsTo(calls, #drawLine), hasLength(1));
    });

    test('skips a pulse that has not appeared yet', () {
      final calls = recordPaint(_painterAt(0), _size);
      expect(callsTo(calls, #drawCircle), hasLength(5));
    });

    test('turns the sweep to the angle of its phase', () {
      for (final t in [0.0, 0.3, 0.77]) {
        final rotate = callsTo(recordPaint(_painterAt(t), _size), #rotate);
        expect(
          rotate.single.positionalArguments.single,
          ScanMath.sweepAngle(t),
        );
      }
    });

    test('places each pulse at the radius its curve gives', () {
      final style = ScanStyle(
        glow: retailScanStyle.glow,
        track: retailScanStyle.track,
        core: retailScanStyle.core,
        period: retailScanStyle.period,
        pulseCurve: Curves.easeIn,
      );
      const t = 0.4;
      final radius = _size.shortestSide / 2 - 2 * (_size.shortestSide / 32);
      final drawn = [
        for (final call in callsTo(
          recordPaint(_painterAt(t, style: style), _size),
          #drawCircle,
        ))
          call.positionalArguments[1] as double,
      ];
      for (var i = 0; i < ScanMath.pulseCount; i++) {
        expect(
          drawn.any(
            (r) =>
                (r -
                        radius *
                            Curves.easeIn.transform(
                              ScanMath.pulseProgress(t, i),
                            ))
                    .abs() <
                1e-9,
          ),
          isTrue,
          reason: 'pulse $i',
        );
      }
    });

    test('lays a wide faint glow under the line of each pulse', () {
      final circles = callsTo(
        recordPaint(_painterAt(ScanMath.restPhase), _size),
        #drawCircle,
      ).toList();
      // Pulses come first, glow then line; the sweep is last.
      for (var k = 0; k < ScanMath.pulseCount; k++) {
        final glow = circles[2 * k].positionalArguments[2] as Paint;
        final line = circles[2 * k + 1].positionalArguments[2] as Paint;
        expect(glow.strokeWidth, closeTo(3 * line.strokeWidth, 1e-9));
        expect(glow.color.a, lessThan(line.color.a));
        expect(
          circles[2 * k].positionalArguments[1],
          circles[2 * k + 1].positionalArguments[1],
        );
      }
    });

    test('keeps every pulse inside the box', () {
      for (final t in [for (var k = 0; k < 50; k++) k / 50]) {
        for (final call in callsTo(
          recordPaint(_painterAt(t), _size),
          #drawCircle,
        )) {
          final radius = call.positionalArguments[1] as double;
          final paint = call.positionalArguments[2] as Paint;
          expect(
            radius + paint.strokeWidth / 2,
            lessThanOrEqualTo(_size.shortestSide / 2),
            reason: 't=$t',
          );
        }
      }
    });

    test('uses no layer, clip, blur, shadow or text', () {
      for (final t in [0.0, ScanMath.restPhase, 0.5, 0.99]) {
        final calls = recordPaint(_painterAt(t), _size);
        for (final member in forbiddenInFrame) {
          expect(callsTo(calls, member), isEmpty, reason: '$member at t=$t');
        }
        for (final call in callsTo(calls, #drawCircle)) {
          final paint = call.positionalArguments[2] as Paint;
          expect(paint.maskFilter, isNull);
          expect(paint.imageFilter, isNull);
          expect(paint.colorFilter, isNull);
        }
      }
    });

    test('balances save and restore', () {
      final calls = recordPaint(_painterAt(0.6), _size);
      expect(callsTo(calls, #save), hasLength(1));
      expect(callsTo(calls, #restore), hasLength(1));
    });

    test('paints nothing into an empty box', () {
      final painter = _painterAt(0.5);
      expect(recordPaint(painter, Size.zero), isEmpty);
      expect(painter.geometryBuilds, 0);
      expect(painter.shaderBuilds, 0);
    });

    test('paints a tiny box without failing', () {
      expect(
        () => recordPaint(_painterAt(0.5), const Size(1, 1)),
        returnsNormally,
      );
    });
  });

  group('allocation', () {
    test('paints only with colours from the prepared palette', () {
      final palette = ScanPalette(retailScanStyle);
      // A Paint keeps its colour as 8-bit channels, so compare those.
      final allowed = {
        for (final color in [...palette.pulse, ...palette.underlay])
          color.toARGB32(),
      };
      final controller = parkedAt(0);
      final painter = SecurityScanPainter(
        animation: controller,
        style: retailScanStyle,
      );
      for (var k = 0; k < 200; k++) {
        controller.value = k / 200;
        final circles = callsTo(recordPaint(painter, _size), #drawCircle);
        // The last circle of a frame is the sweep, filled by its shader.
        for (final call in circles.take(circles.length - 1)) {
          final paint = call.positionalArguments[2] as Paint;
          expect(
            allowed,
            contains(paint.color.toARGB32()),
            reason: 't=${k / 200}',
          );
        }
      }
    });

    test('builds the geometry and the shader once, not per frame', () {
      final controller = parkedAt(0);
      final painter = SecurityScanPainter(
        animation: controller,
        style: retailScanStyle,
      );
      for (var k = 0; k < 200; k++) {
        controller.value = k / 200;
        recordPaint(painter, _size);
      }
      expect(painter.geometryBuilds, 1);
      expect(painter.shaderBuilds, 1);
    });

    test('rebuilds the geometry for a new size, and the shader never', () {
      final painter = _painterAt(0.5);
      recordPaint(painter, _size);
      recordPaint(painter, const Size(120, 120));
      recordPaint(painter, const Size(120, 120));
      recordPaint(painter, _size);
      expect(painter.geometryBuilds, 3);
      expect(painter.shaderBuilds, 1);
    });
  });
}
