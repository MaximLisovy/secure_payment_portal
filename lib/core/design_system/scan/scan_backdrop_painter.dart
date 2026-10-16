import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_style.dart';

/// The still part of the security scan: three rings, a crosshair, twelve ticks
/// and a centre dot. It sits in its own repaint layer under the moving part, so
/// it is painted once per size and then reused, never per frame.
class ScanBackdropPainter extends CustomPainter {
  ScanBackdropPainter(this.style);

  final ScanStyle style;

  static const _ringShares = [1.0, 2 / 3, 1 / 3];
  static const _tickCount = 12;
  static const _tickLength = 0.08;

  late final Paint _trackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = style.track;
  late final Paint _corePaint = Paint()..color = style.core;
  final Path _marks = Path();

  Size? _size;
  Offset _center = Offset.zero;
  double _radius = 0;
  double _stroke = 0;

  /// How many times the geometry was built, for tests: once per size.
  @visibleForTesting
  int geometryBuilds = 0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _prepare(size);
    for (final share in _ringShares) {
      canvas.drawCircle(_center, _radius * share, _trackPaint);
    }
    canvas
      ..drawPath(_marks, _trackPaint)
      ..drawCircle(_center, _stroke * 1.5, _corePaint);
  }

  void _prepare(Size size) {
    if (size == _size) return;
    _size = size;
    final side = size.shortestSide;
    _stroke = side / 32;
    _radius = side / 2 - 2 * _stroke;
    _center = size.center(Offset.zero);
    _trackPaint.strokeWidth = _stroke * 0.75;

    _marks.reset();
    // The crosshair.
    _marks
      ..moveTo(_center.dx - _radius, _center.dy)
      ..lineTo(_center.dx + _radius, _center.dy)
      ..moveTo(_center.dx, _center.dy - _radius)
      ..lineTo(_center.dx, _center.dy + _radius);
    // The ticks, just inside the outer ring.
    for (var k = 0; k < _tickCount; k++) {
      final angle = 2 * math.pi * k / _tickCount;
      final direction = Offset.fromDirection(angle);
      _marks
        ..moveTo(
          _center.dx + direction.dx * _radius * (1 - _tickLength),
          _center.dy + direction.dy * _radius * (1 - _tickLength),
        )
        ..lineTo(
          _center.dx + direction.dx * _radius,
          _center.dy + direction.dy * _radius,
        );
    }
    geometryBuilds++;
  }

  @override
  bool shouldRepaint(ScanBackdropPainter oldDelegate) =>
      oldDelegate.style != style;
}
