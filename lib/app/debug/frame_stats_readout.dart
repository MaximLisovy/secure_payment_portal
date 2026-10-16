import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/app/debug/frame_stats_collector.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';

class FrameStatsReadout extends ConsumerWidget {
  const FrameStatsReadout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(frameStatsProvider);
    String time(double ms) =>
        stats.windowFrames == 0 ? '—' : ms.toStringAsFixed(2);
    final build = stats.build;
    final raster = stats.raster;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(AppStrings.frameStatsTitle),
        Text(
          AppStrings.frameStatsCounts(stats.totalFrames, stats.windowFrames),
        ),
        Text(
          AppStrings.frameStatsRefreshRate(
            View.of(context).display.refreshRate,
          ),
        ),
        Table(
          children: [
            const TableRow(
              children: [
                Text(AppStrings.frameStatsMs),
                Text(AppStrings.frameStatsBuild),
                Text(AppStrings.frameStatsRaster),
              ],
            ),
            for (final (label, buildMs, rasterMs) in [
              (AppStrings.frameStatsP50, build.p50, raster.p50),
              (AppStrings.frameStatsP90, build.p90, raster.p90),
              (AppStrings.frameStatsP99, build.p99, raster.p99),
              (AppStrings.frameStatsWorst, build.worst, raster.worst),
            ])
              TableRow(
                children: [
                  Text(label),
                  Text(time(buildMs)),
                  Text(time(rasterMs)),
                ],
              ),
          ],
        ),
        TextButton(
          onPressed: () => ref.read(frameStatsProvider.notifier).reset(),
          child: const Text(AppStrings.frameStatsReset),
        ),
      ],
    );
  }
}
