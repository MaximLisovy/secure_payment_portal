import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/brands/brand_config.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/brands/utility/utility_brand.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_animation.dart';
import 'package:secure_payment_portal/core/design_system/scan/security_scan_painter.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_notifier.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_state.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/security_scan_indicator.dart';
import 'package:secure_payment_portal/features/payment/presentation/views/security_scan_slot.dart';
import 'package:secure_payment_portal/features/security/security_domain.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/rebuild_tracker.dart';

/// A flow the test moves by hand, state by state.
class _ScriptedFlow extends PaymentFlowNotifier {
  _ScriptedFlow(this.first);

  final PaymentFlowState first;

  @override
  PaymentFlowState build() => first;

  void emit(PaymentFlowState next) => state = next;
}

const _checking = PaymentFlowSecurityCheck();
const _ready = PaymentFlowReady();
const _blocked = PaymentFlowBlocked(SecurityBlockReason.screenRecording);

Future<(ProviderContainer, _ScriptedFlow)> _pump(
  WidgetTester tester, {
  PaymentFlowState first = _checking,
  BrandConfig? brand,
  bool reducedMotion = false,
}) async {
  final flow = _ScriptedFlow(first);
  final container = await tester.pumpApp(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: const Scaffold(
          body: CustomScrollView(slivers: [SecurityScanSlot()]),
        ),
      ),
    ),
    brand: brand ?? retailBrand,
    overrides: [paymentFlowProvider.overrideWith(() => flow)],
  );
  return (container, flow);
}

Finder get _scan => find.byType(ScanAnimation);
Finder get _verifiedIcon => find.byIcon(Icons.verified_user_outlined);
Finder get _blockedIcon => find.byIcon(Icons.gpp_bad_outlined);

SecurityScanPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(of: _scan, matching: find.byType(CustomPaint)),
    )
    .map((paint) => paint.painter)
    .whereType<SecurityScanPainter>()
    .single;

double _phase(WidgetTester tester) => _painter(tester).animation.value;

void main() {
  group('what each state shows', () {
    testWidgets('checking shows the scan and the checking text', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump();
      expect(_scan, findsOneWidget);
      expect(_verifiedIcon, findsNothing);
      expect(_blockedIcon, findsNothing);
      expect(find.text(AppStrings.securityChecking), findsOneWidget);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('the idle flow shows the scan as well', (tester) async {
      await _pump(tester, first: const PaymentFlowIdle());
      expect(_scan, findsOneWidget);
    });

    testWidgets('ready shows the verified mark and nothing moves', (
      tester,
    ) async {
      await _pump(tester, first: _ready);
      await tester.pumpAndSettle();
      expect(_verifiedIcon, findsOneWidget);
      expect(_scan, findsNothing);
      expect(find.text(AppStrings.securityVerified), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('blocked shows the blocked mark and nothing moves', (
      tester,
    ) async {
      await _pump(tester, first: _blocked);
      await tester.pumpAndSettle();
      expect(_blockedIcon, findsOneWidget);
      expect(_scan, findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('the verdict arriving', () {
    testWidgets('lets the sweep keep turning while it fades out', (
      tester,
    ) async {
      final (_, flow) = await _pump(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final before = _phase(tester);

      flow.emit(_ready);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(_scan, findsOneWidget, reason: 'still fading out');
      expect(_verifiedIcon, findsOneWidget);
      expect(_phase(tester), isNot(before));
    });

    testWidgets('then removes the scan and stops its ticker', (tester) async {
      final (_, flow) = await _pump(tester);
      await tester.pump();
      flow.emit(_ready);
      await tester.pumpAndSettle();
      expect(_scan, findsNothing);
      expect(_verifiedIcon, findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('checking again starts a new scan', (tester) async {
      final (_, flow) = await _pump(tester, first: _blocked);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);

      flow.emit(_checking);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_scan, findsOneWidget);
      expect(_blockedIcon, findsNothing);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('with reduced motion the swap is immediate and still', (
      tester,
    ) async {
      final (_, flow) = await _pump(tester, reducedMotion: true);
      await tester.pump();
      expect(_scan, findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);

      flow.emit(_ready);
      await tester.pump();
      expect(_scan, findsNothing);
      expect(_verifiedIcon, findsOneWidget);
    });
  });

  group('while checking', () {
    testWidgets('a second of frames rebuilds nothing, not even the card', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump();
      final rebuilt = await rebuiltDuring(() async {
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      });
      expect(rebuilt, isEmpty);
    });

    testWidgets('the text beside the scan is not repainted', (tester) async {
      await _pump(tester);
      await tester.pump();
      RenderObject? node = tester.renderObject(
        find.text(AppStrings.securityChecking),
      );
      while (node != null && node is! RenderRepaintBoundary) {
        node = node.parent;
      }
      final boundary = node! as RenderRepaintBoundary;
      int paints() =>
          boundary.debugSymmetricPaintCount +
          boundary.debugAsymmetricPaintCount;
      final before = paints();

      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(paints(), before);
    });
  });

  group('size', () {
    for (final brand in [retailBrand, utilityBrand]) {
      testWidgets('${brand.id}: the mark is one box in every state', (
        tester,
      ) async {
        // One and a half controls: 78 for Retail (52), 66 for Utility (44).
        final expected = brand.tokens.density.controlHeight * 1.5;
        final (_, flow) = await _pump(tester, brand: brand);
        await tester.pump();
        final sizes = <Size>[
          tester.getSize(find.byType(SecurityScanIndicator)),
        ];
        for (final next in [_ready, _blocked, _checking]) {
          flow.emit(next);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          sizes.add(tester.getSize(find.byType(SecurityScanIndicator)));
        }
        for (final size in sizes) {
          expect(size, Size.square(expected));
        }
      });
    }
  });
}
