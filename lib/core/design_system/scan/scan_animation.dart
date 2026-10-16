import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_backdrop_painter.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_math.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_style.dart';
import 'package:secure_payment_portal/core/design_system/scan/security_scan_painter.dart';

/// The security scan: a radar sweep with staggered pulses, in the brand's
/// colours and rhythm.
///
/// The only thing that changes per frame is the paint of one layer:
///
/// ```
/// SizedBox.square
/// └─ Stack
///    ├─ RepaintBoundary ─ CustomPaint(ScanBackdropPainter)       still, painted once
///    └─ RepaintBoundary ─ CustomPaint(SecurityScanPainter,       repaints every frame,
///                                     willChange: true)          rebuilds nothing
/// ```
///
/// This state owns the one [AnimationController], created for this widget and
/// disposed with it: the ticker runs exactly as long as the scan is on screen.
/// With reduced motion (`MediaQuery.disableAnimationsOf`) no ticker starts and
/// the scan stays on a still pose.
class ScanAnimation extends StatefulWidget {
  const ScanAnimation({required this.dimension, super.key});

  /// Side of the square the scan is drawn in.
  final double dimension;

  @override
  State<ScanAnimation> createState() => _ScanAnimationState();
}

class _ScanAnimationState extends State<ScanAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  ScanStyle? _style;
  late SecurityScanPainter _painter;
  late ScanBackdropPainter _backdrop;
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final style = ScanStyle.from(context.brandColors, context.brandMotion);
    final styleChanged = style != _style;
    if (styleChanged) {
      // New painters only when the brand's tokens change, never on a rebuild.
      _style = style;
      _painter = SecurityScanPainter(animation: _controller, style: style);
      _backdrop = ScanBackdropPainter(style);
      _controller.duration = style.period;
    }
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      // Setting the value also stops the ticker.
      _controller.value = ScanMath.restPhase;
    } else if (styleChanged || !_controller.isAnimating) {
      // Starts from the current value, so a brand switch does not jump.
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.dimension,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: _backdrop, isComplex: true),
          ),
          RepaintBoundary(
            child: CustomPaint(painter: _painter, willChange: !_reducedMotion),
          ),
        ],
      ),
    );
  }
}
