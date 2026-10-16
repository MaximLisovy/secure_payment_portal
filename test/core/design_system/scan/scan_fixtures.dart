import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/brands/utility/utility_brand.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_style.dart';

/// The scan as each shipped brand resolves it.
final retailScanStyle = ScanStyle.from(
  retailBrand.tokens.colors,
  retailBrand.tokens.motion,
);
final utilityScanStyle = ScanStyle.from(
  utilityBrand.tokens.colors,
  utilityBrand.tokens.motion,
);

/// A controller parked at [value], for painting a single frame.
AnimationController parkedAt(double value) {
  final controller = AnimationController(
    vsync: const TestVSync(),
    duration: const Duration(seconds: 2),
  )..value = value;
  addTearDown(controller.dispose);
  return controller;
}

/// What a painter asked of the canvas for one frame.
List<Invocation> recordPaint(CustomPainter painter, Size size) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, size);
  return [for (final recorded in canvas.invocations) recorded.invocation];
}

Iterable<Invocation> callsTo(List<Invocation> calls, Symbol member) =>
    calls.where((call) => call.memberName == member);

/// Operations the performance rules keep out of a frame.
const forbiddenInFrame = <Symbol>[
  #saveLayer,
  #clipPath,
  #clipRRect,
  #clipRect,
  #drawShadow,
  #drawParagraph,
  #drawImage,
];
