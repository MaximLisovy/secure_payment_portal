import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_providers.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/brands/utility/utility_brand.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_animation.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_math.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_style.dart';
import 'package:secure_payment_portal/core/design_system/scan/security_scan_painter.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/rebuild_tracker.dart';

/// Counts how often it is painted, to see whether the layer around it repaints.
class _Probe extends CustomPainter {
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) => paints++;

  @override
  bool shouldRepaint(_Probe oldDelegate) => false;
}

Widget _scan({bool reducedMotion = false, _Probe? probe}) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
    child: Column(
      children: [
        if (probe != null)
          SizedBox(height: 20, child: CustomPaint(painter: probe)),
        const ScanAnimation(dimension: 78),
        if (probe != null)
          SizedBox(height: 20, child: CustomPaint(painter: probe)),
      ],
    ),
  ),
);

/// Pumps the scan under the real root providers. Calling it again replaces the
/// widget but keeps the same app, so the scan's state survives.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  BrandConfig? brand,
  bool reducedMotion = false,
  _Probe? probe,
}) => tester.pumpApp(
  _scan(reducedMotion: reducedMotion, probe: probe),
  brand: brand ?? retailBrand,
);

SecurityScanPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(ScanAnimation),
        matching: find.byType(CustomPaint),
      ),
    )
    .map((paint) => paint.painter)
    .whereType<SecurityScanPainter>()
    .single;

AnimationController _controller(WidgetTester tester) =>
    _painter(tester).animation as AnimationController;

double _phase(WidgetTester tester) => _controller(tester).value;

/// The scan's two layers: the still backdrop, then the moving part.
({RenderRepaintBoundary backdrop, RenderRepaintBoundary moving}) _layers(
  WidgetTester tester,
) {
  final boundaries = tester
      .renderObjectList<RenderRepaintBoundary>(
        find.descendant(
          of: find.byType(ScanAnimation),
          matching: find.byType(RepaintBoundary),
        ),
      )
      .toList();
  return (backdrop: boundaries[0], moving: boundaries[1]);
}

/// The layer the page lives in: the nearest repaint boundary above the scan.
RenderRepaintBoundary _pageLayer(WidgetTester tester) {
  RenderObject? node = tester.renderObject(find.byType(ScanAnimation)).parent;
  while (node != null && node is! RenderRepaintBoundary) {
    node = node.parent;
  }
  return node! as RenderRepaintBoundary;
}

/// How often a boundary's layer was painted, alone or with its parent.
int _paints(RenderRepaintBoundary boundary) =>
    boundary.debugSymmetricPaintCount + boundary.debugAsymmetricPaintCount;

Future<void> _runFrames(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  group('rebuilds', () {
    testWidgets('a second of frames rebuilds no widget at all', (tester) async {
      await _pump(tester);
      await tester.pump();
      final before = _phase(tester);

      final rebuilt = await rebuiltDuring(() => _runFrames(tester, 60));

      expect(rebuilt, isEmpty);
      expect(_phase(tester), isNot(before), reason: 'and it did move');
    });
  });

  group('repaints', () {
    testWidgets('only the moving layer repaints, once per frame', (
      tester,
    ) async {
      final probe = _Probe();
      await _pump(tester, probe: probe);
      await tester.pump();
      final (:backdrop, :moving) = _layers(tester);
      final page = _pageLayer(tester);
      final probesBefore = probe.paints;
      final backdropBefore = _paints(backdrop);
      final movingBefore = moving.debugAsymmetricPaintCount;
      final movingTogetherBefore = moving.debugSymmetricPaintCount;
      final pageBefore = _paints(page);

      await _runFrames(tester, 60);

      expect(
        moving.debugAsymmetricPaintCount - movingBefore,
        inInclusiveRange(58, 61),
        reason: 'the sweep repaints on every frame, on its own',
      );
      expect(
        moving.debugSymmetricPaintCount,
        movingTogetherBefore,
        reason: 'and never together with the page',
      );
      expect(
        _paints(backdrop),
        backdropBefore,
        reason: 'the backdrop is still',
      );
      expect(_paints(page), pageBefore, reason: 'the page is not repainted');
      expect(probe.paints, probesBefore, reason: 'neither are the neighbours');
    });
  });

  group('time', () {
    testWidgets('the phase follows elapsed time, not the frame rate', (
      tester,
    ) async {
      Future<double> phaseAfter(Duration step, int steps) async {
        await tester.pumpWidget(const SizedBox());
        await _pump(tester);
        await tester.pump(); // The ticker starts on this frame.
        for (var i = 0; i < steps; i++) {
          await tester.pump(step);
        }
        return _phase(tester);
      }

      // 600 ms of a 2400 ms period, at three frame rates.
      final at120Hz = await phaseAfter(const Duration(microseconds: 8000), 75);
      final at50Hz = await phaseAfter(const Duration(milliseconds: 20), 30);
      final slow = await phaseAfter(const Duration(milliseconds: 100), 6);

      expect(at50Hz, closeTo(0.25, 0.005));
      expect(at120Hz, closeTo(at50Hz, 0.005));
      expect(slow, closeTo(at50Hz, 0.005));
    });

    for (final brand in [retailBrand, utilityBrand]) {
      testWidgets('${brand.id} repeats once per its period', (tester) async {
        final period = ScanStyle.periodFor(brand.tokens.motion);
        await _pump(tester, brand: brand);
        await tester.pump();
        expect(_controller(tester).duration, period);

        await tester.pump(period * 1.25);
        expect(_phase(tester), closeTo(0.25, 0.01));
        await tester.pump(period * 2);
        expect(_phase(tester), closeTo(0.25, 0.01));
      });
    }

    testWidgets('never reaches the end of the loop, so there is no seam', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump();
      for (var i = 0; i < 400; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(_phase(tester), inInclusiveRange(0, 1));
        expect(_phase(tester), lessThan(1));
      }
    });
  });

  group('ticker', () {
    testWidgets('runs while the scan is on screen and stops when it is gone', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('reduced motion', () {
    testWidgets('starts no ticker and shows the still pose', (tester) async {
      await _pump(tester, reducedMotion: true);
      await _runFrames(tester, 10);
      expect(tester.binding.transientCallbackCount, 0);
      expect(_phase(tester), ScanMath.restPhase);
    });

    testWidgets('still draws the scan, once', (tester) async {
      await _pump(tester, reducedMotion: true);
      final (:backdrop, :moving) = _layers(tester);
      expect(_paints(backdrop), greaterThan(0));
      expect(_paints(moving), greaterThan(0));
      final before = _paints(moving);
      await _runFrames(tester, 30);
      expect(_paints(moving), before);
    });

    testWidgets('follows the setting while the scan is on screen', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      final painter = _painter(tester);

      await _pump(tester, reducedMotion: true);
      await _runFrames(tester, 5);
      expect(tester.binding.transientCallbackCount, 0);
      expect(_phase(tester), ScanMath.restPhase);
      expect(
        identical(_painter(tester), painter),
        isTrue,
        reason: 'the setting is not a reason to rebuild the painters',
      );

      await _pump(tester);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });
  });

  group('brand', () {
    testWidgets('a rebuild with the same tokens keeps the same painter', (
      tester,
    ) async {
      await _pump(tester);
      final before = _painter(tester);
      await _pump(tester);
      expect(identical(_painter(tester), before), isTrue);
    });

    testWidgets('a brand switch restyles the scan and retimes it', (
      tester,
    ) async {
      final container = await _pump(tester);
      await tester.pump();
      expect(_painter(tester).style.period, const Duration(milliseconds: 2400));

      container.read(activeBrandProvider.notifier).select('utility');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final utility = _painter(tester);
      expect(utility.style.glow, utilityBrand.tokens.colors.scanGlow);
      expect(utility.style.period, ScanStyle.minPeriod);
      expect(_controller(tester).duration, ScanStyle.minPeriod);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });
  });
}
