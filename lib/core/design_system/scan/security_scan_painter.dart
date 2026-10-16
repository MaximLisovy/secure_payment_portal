import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_math.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_palette.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_style.dart';

/// The moving part of the security scan: three staggered pulses and a radar
/// sweep, on top of [ScanBackdropPainter]'s static rings. The maths is in
/// [ScanMath].
///
/// It listens to [animation] itself (`super(repaint: animation)`), so a frame
/// repaints this layer and rebuilds nothing. `shouldRepaint` therefore compares
/// the style only.
///
/// Drawing a frame allocates nothing: the `Paint`s are fields, the colours come
/// from [ScanPalette], the sweep shader and the geometry are built once (the
/// geometry again only if the size changes), and there is no `saveLayer`, clip,
/// blur or shadow. The painter never sees a `BuildContext` or a `Theme`.
class SecurityScanPainter extends CustomPainter {
  SecurityScanPainter({required this.animation, required this.style})
    : _palette = ScanPalette(style),
      _ease = style.pulseCurve.transform,
      super(repaint: animation);

  final Animation<double> animation;
  final ScanStyle style;

  final ScanPalette _palette;
  final double Function(double) _ease;

  final Paint _sweepPaint = Paint();
  final Paint _edgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _pulsePaint = Paint()..style = PaintingStyle.stroke;

  Size? _size;
  Offset _center = Offset.zero;
  Offset _edgeEnd = Offset.zero;
  double _radius = 0;
  double _stroke = 0;
  bool _hasShader = false;

  /// How many times the geometry and the shader were built, for tests: they
  /// must stay flat across frames and rise only when the size changes.
  @visibleForTesting
  int geometryBuilds = 0;
  @visibleForTesting
  int shaderBuilds = 0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _prepare(size);
    final t = animation.value;

    for (var i = 0; i < ScanMath.pulseCount; i++) {
      final progress = ScanMath.pulseProgress(t, i);
      final level = ScanMath.alphaLevel(ScanMath.pulseEnvelope(progress));
      if (level == 0) continue;
      final radius = _radius * ScanMath.pulseRadiusFraction(progress, _ease);
      final width = _stroke * ScanMath.pulseStrokeScale(progress);
      _pulsePaint
        ..strokeWidth = width * 3
        ..color = _palette.underlay[level];
      canvas.drawCircle(_center, radius, _pulsePaint);
      _pulsePaint
        ..strokeWidth = width
        ..color = _palette.pulse[level];
      canvas.drawCircle(_center, radius, _pulsePaint);
    }

    canvas
      ..save()
      ..translate(_center.dx, _center.dy)
      ..rotate(ScanMath.sweepAngle(t))
      ..drawCircle(Offset.zero, _radius, _sweepPaint)
      ..drawLine(Offset.zero, _edgeEnd, _edgePaint)
      ..restore();
  }

  void _prepare(Size size) {
    if (!_hasShader) {
      // The gradient lives in the sweep's own frame, turning with the canvas, so
      // it does not depend on the size.
      _sweepPaint.shader = ui.Gradient.sweep(
        Offset.zero,
        _palette.sweep,
        ScanMath.sweepStops,
        TileMode.clamp,
        0,
        2 * math.pi,
      );
      _edgePaint.color = _palette.edge;
      _hasShader = true;
      shaderBuilds++;
    }
    if (size == _size) return;
    _size = size;
    final side = size.shortestSide;
    _stroke = side / 32;
    _radius = side / 2 - 2 * _stroke;
    _center = size.center(Offset.zero);
    _edgeEnd = Offset(_radius, 0);
    _edgePaint.strokeWidth = _stroke;
    geometryBuilds++;
  }

  @override
  bool shouldRepaint(SecurityScanPainter oldDelegate) =>
      oldDelegate.style != style;
}
