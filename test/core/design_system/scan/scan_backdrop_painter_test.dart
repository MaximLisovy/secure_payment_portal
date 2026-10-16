import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_backdrop_painter.dart';

import 'scan_fixtures.dart';

const _size = Size(78, 78);

void main() {
  test('shouldRepaint follows the style', () {
    final painter = ScanBackdropPainter(retailScanStyle);
    expect(
      painter.shouldRepaint(ScanBackdropPainter(retailScanStyle)),
      isFalse,
    );
    expect(
      painter.shouldRepaint(ScanBackdropPainter(utilityScanStyle)),
      isTrue,
    );
  });

  test('draws three rings, the dot and one path of marks', () {
    final calls = recordPaint(ScanBackdropPainter(retailScanStyle), _size);
    expect(callsTo(calls, #drawCircle), hasLength(4));
    expect(callsTo(calls, #drawPath), hasLength(1));
  });

  test('uses no layer, clip, blur, shadow or text', () {
    final calls = recordPaint(ScanBackdropPainter(retailScanStyle), _size);
    for (final member in forbiddenInFrame) {
      expect(callsTo(calls, member), isEmpty, reason: '$member');
    }
  });

  test('builds its geometry once per size', () {
    final painter = ScanBackdropPainter(retailScanStyle);
    for (var k = 0; k < 20; k++) {
      recordPaint(painter, _size);
    }
    expect(painter.geometryBuilds, 1);
    recordPaint(painter, const Size(100, 100));
    expect(painter.geometryBuilds, 2);
  });

  test('paints nothing into an empty box', () {
    expect(
      recordPaint(ScanBackdropPainter(retailScanStyle), Size.zero),
      isEmpty,
    );
  });

  test('is the track and core colour of the style', () {
    final calls = recordPaint(ScanBackdropPainter(retailScanStyle), _size);
    final circles = callsTo(calls, #drawCircle).toList();
    final ring = circles.first.positionalArguments[2] as Paint;
    final dot = circles.last.positionalArguments[2] as Paint;
    expect(ring.color.toARGB32(), retailScanStyle.track.toARGB32());
    expect(dot.color.toARGB32(), retailScanStyle.core.toARGB32());
  });
}
