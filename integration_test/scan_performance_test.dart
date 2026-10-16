import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:secure_payment_portal/app/app.dart';
import 'package:secure_payment_portal/app/brand/brand_providers.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/app/di/root_overrides.dart';
import 'package:secure_payment_portal/app/di/scan_dwell_overrides.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_animation.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_style.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/security_scan_indicator.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';

/// Frame timing of the security scan, for every registered brand.
///
/// Run in profile mode, on a device, from the project root:
///
/// ```
/// flutter drive --profile --no-dds --flavor retail -d <device id> \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/scan_performance_test.dart \
///   --dart-define=DEVICE_NAME="<what to call the device>"
/// ```
///
/// (`--no-dds`: the test reads the VM service itself.) One build measures every
/// brand, because the brand is injected in process the way the app does it, so a
/// brand added to the registry is measured with no change here. The driver writes
/// `build/scan_performance/summary.md`.
///
/// Each brand is measured four ways, each [_repeats] times:
///  * `scan-in-app`: the real app with the scan running (a check that never ends);
///  * `scan-alone`: the scan indicator alone on an empty page;
///  * `spinner-alone`: Material's own spinner alone on an empty page, the cost of
///    a stock widget that animates for ever, to read the scan against;
///  * `floor-alone`: a layer that repaints every frame and draws one dot, the
///    least a continuously animating layer can cost on this device. The scan's
///    cost is what it adds to this floor: on an emulator the raster time is
///    mostly the emulator's own swap, which the floor shows.
const _warmUp = Duration(seconds: 2);
const _window = Duration(seconds: 8);
const _repeats = 3;

enum _Variant {
  scanInApp('scan-in-app'),
  scanAlone('scan-alone'),
  spinnerAlone('spinner-alone'),
  floorAlone('floor-alone');

  const _Variant(this.label);

  final String label;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('security scan frame timing', (tester) async {
    final display = tester.view.display;
    final brands = BrandRegistry.standard.all.toList();
    binding.reportData ??= <String, dynamic>{};
    binding.reportData!['meta'] = <String, dynamic>{
      'device': const String.fromEnvironment(
        'DEVICE_NAME',
        defaultValue: 'unnamed device',
      ),
      'mode': kProfileMode
          ? 'profile'
          : kReleaseMode
          ? 'release'
          : 'debug',
      'refreshRate': display.refreshRate,
      'budgetMs': 1000 / display.refreshRate,
      'windowSeconds': _window.inSeconds,
      'warmUpSeconds': _warmUp.inSeconds,
      'repeats': _repeats,
      'scanPeriodMs': {
        for (final brand in brands)
          brand.id: ScanStyle.periodFor(brand.tokens.motion).inMilliseconds,
      },
    };

    for (final brand in brands) {
      for (final variant in _Variant.values) {
        for (var repeat = 1; repeat <= _repeats; repeat++) {
          await _mount(tester, variant, brand);
          await tester.pump(_warmUp);
          expect(
            find.byType(switch (variant) {
              _Variant.spinnerAlone => CircularProgressIndicator,
              _Variant.floorAlone => _Floor,
              _ => ScanAnimation,
            }),
            findsOneWidget,
            reason: '${brand.id}/${variant.label} is not animating',
          );
          await binding.watchPerformance(
            () => tester.pump(_window),
            reportKey: '${brand.id}/${variant.label}/$repeat',
          );
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}

Future<void> _mount(
  WidgetTester tester,
  _Variant variant,
  BrandConfig brand,
) async {
  final size =
      brand.tokens.density.controlHeight * SecurityScanIndicator.sizeFactor;
  switch (variant) {
    case _Variant.scanInApp:
      await tester.pumpWidget(
        ProviderScope(
          retry: disableProviderRetry,
          overrides: [
            ...rootOverrides(initialBrand: brand),
            ...scanDwellOverrides(),
            // A device check that never finishes, so the scan runs throughout.
            realSecurityPlatformDataSourceProvider.overrideWith((ref) {
              final fake = FakeSecurityPlatformDataSource(
                latency: const Duration(hours: 1),
              );
              ref.onDispose(fake.dispose);
              return fake;
            }),
          ],
          child: const App(),
        ),
      );
      // The bill loads, then the check starts.
      await tester.pump(const Duration(seconds: 2));
    case _Variant.scanAlone:
      await tester.pumpWidget(
        _emptyPage(
          brand,
          const SecurityScanIndicator(status: ScanIndicatorStatus.checking),
        ),
      );
    case _Variant.floorAlone:
      await tester.pumpWidget(_emptyPage(brand, _Floor(dimension: size)));
    case _Variant.spinnerAlone:
      await tester.pumpWidget(
        _emptyPage(
          brand,
          SizedBox.square(
            dimension: size,
            child: const CircularProgressIndicator(),
          ),
        ),
      );
  }
}

Widget _emptyPage(BrandConfig brand, Widget child) => ProviderScope(
  retry: disableProviderRetry,
  overrides: rootOverrides(initialBrand: brand),
  child: Consumer(
    builder: (context, ref, _) => MaterialApp(
      theme: ref.watch(themeProvider),
      home: Scaffold(body: Center(child: child)),
    ),
  ),
);

/// A layer that repaints on every frame and draws a single dot: the cheapest
/// continuously animating layer there is, on the same footing as the scan (its
/// own repaint boundary, repainting through its listenable, no rebuilds).
class _Floor extends StatefulWidget {
  const _Floor({required this.dimension});

  final double dimension;

  @override
  State<_Floor> createState() => _FloorState();
}

class _FloorState extends State<_Floor> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.dimension,
    child: RepaintBoundary(
      child: CustomPaint(painter: _FloorPainter(_controller), willChange: true),
    ),
  );
}

class _FloorPainter extends CustomPainter {
  _FloorPainter(Animation<double> animation) : super(repaint: animation);

  final Paint _paint = Paint()..color = const Color(0x01000000);

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawCircle(const Offset(1, 1), 1, _paint);

  @override
  bool shouldRepaint(_FloorPainter oldDelegate) => false;
}
