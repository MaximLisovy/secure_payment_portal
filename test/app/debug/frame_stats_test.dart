import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/debug/frame_stats.dart';
import 'package:secure_payment_portal/app/debug/frame_stats_collector.dart';
import 'package:secure_payment_portal/app/debug/frame_stats_readout.dart';
import 'package:secure_payment_portal/brands/retail/retail_brand.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';

import '../../helpers/pump_app.dart';

FrameTiming _frame() => FrameTiming(
  vsyncStart: 0,
  buildStart: 100,
  buildFinish: 1100,
  rasterStart: 1200,
  rasterFinish: 3200,
  rasterFinishWallTime: 3200,
);

class _RecordingStats extends FrameStatsNotifier {
  int recorded = 0;
  @override
  void record(List<FrameTiming> timings) {
    recorded += timings.length;
    super.record(timings);
  }
}

void main() {
  test(
    'nearest-rank percentiles retain outliers separately for build and raster',
    () {
      final window = FrameStatsWindow();
      expect(window.snapshot(), const FrameStatsSnapshot());
      for (var i = 1; i <= 100; i++) {
        window.add(
          build: Duration(milliseconds: i),
          raster: Duration(milliseconds: i * 2),
        );
      }
      final stats = window.snapshot();
      expect(stats.totalFrames, 100);
      expect(stats.build, const FramePercentiles(50, 90, 99, 100));
      expect(stats.raster, const FramePercentiles(100, 180, 198, 200));
    },
  );

  test(
    'rolling window evicts old outliers and reset clears count and samples',
    () {
      final window = FrameStatsWindow(capacity: 3);
      for (final ms in [1000, 10, 20, 30]) {
        window.add(
          build: Duration(milliseconds: ms),
          raster: Duration(milliseconds: ms * 2),
        );
      }
      final stats = window.snapshot();
      expect(stats.totalFrames, 4);
      expect(stats.windowFrames, 3);
      expect(stats.build, const FramePercentiles(20, 30, 30, 30));
      window.reset();
      expect(window.snapshot(), const FrameStatsSnapshot());
    },
  );

  test('recording timing batches does not publish state per frame', () {
    final container = ProviderContainer.test();
    final notifier = container.read(frameStatsProvider.notifier);
    notifier.record([_frame(), _frame()]);
    expect(container.read(frameStatsProvider).totalFrames, 0);
    notifier.publish();
    expect(container.read(frameStatsProvider).totalFrames, 2);
    notifier.reset();
    expect(container.read(frameStatsProvider), const FrameStatsSnapshot());
  });

  testWidgets(
    'collector reports engine timings, resets, and releases its callback',
    (tester) async {
      final stats = _RecordingStats();
      await tester.pumpApp(
        const FrameStatsCollector(child: Scaffold(body: FrameStatsReadout())),
        brand: retailBrand,
        overrides: [frameStatsProvider.overrideWith(() => stats)],
      );
      tester.binding.platformDispatcher.onReportTimings?.call([_frame()]);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(AppStrings.frameStatsCounts(1, 1)), findsOneWidget);
      expect(find.text('1.00'), findsNWidgets(4));
      expect(find.text('2.00'), findsNWidgets(4));
      expect(find.textContaining('Display reports:'), findsOneWidget);
      await tester.tap(find.text(AppStrings.frameStatsReset));
      await tester.pump();
      expect(find.text(AppStrings.frameStatsCounts(0, 0)), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      final recorded = stats.recorded;
      tester.binding.platformDispatcher.onReportTimings?.call([_frame()]);
      expect(
        stats.recorded,
        recorded,
        reason: 'unmounted collector must release its callback',
      );
    },
  );
}
