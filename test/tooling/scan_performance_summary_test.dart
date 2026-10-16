import 'package:flutter_test/flutter_test.dart';

import '../../test_driver/scan_performance_summary.dart';

Map<String, dynamic> _run({
  required int frames,
  required double buildAvg,
  required double rasterAvg,
  List<int>? buildTimes,
  List<int>? rasterTimes,
  int gc = 2,
}) => {
  'frame_count': frames,
  'average_frame_build_time_millis': buildAvg,
  '90th_percentile_frame_build_time_millis': buildAvg * 2,
  'worst_frame_build_time_millis': buildAvg * 4,
  'average_frame_rasterizer_time_millis': rasterAvg,
  '90th_percentile_frame_rasterizer_time_millis': rasterAvg * 2,
  'worst_frame_rasterizer_time_millis': rasterAvg * 4,
  'frame_build_times': buildTimes ?? [1000, 2000],
  'frame_rasterizer_times': rasterTimes ?? [1000, 2000],
  'new_gen_gc_count': gc,
};

Map<String, dynamic> _meta({String mode = 'profile'}) => {
  'device': 'Test device',
  'mode': mode,
  'refreshRate': 60.0,
  'budgetMs': 1000 / 60,
  'windowSeconds': 10,
  'repeats': 3,
};

void main() {
  group('median', () {
    test('is the middle value, whatever the order', () {
      expect(median([3, 1, 2]), 2);
      expect(median([9, 1, 5, 7, 3]), 5);
    });

    test('is the mean of the middle two for an even count', () {
      expect(median([4, 1, 2, 3]), 2.5);
    });

    test('is the value itself for one', () {
      expect(median([7]), 7);
    });

    test('rejects an empty list', () {
      expect(() => median([]), throwsArgumentError);
    });
  });

  group('framesOver', () {
    test('counts the frames longer than the budget', () {
      // 16.67 ms budget: 16 ms is inside, 17 ms and 40 ms are over.
      expect(framesOver([16000, 17000, 40000, 1000], 1000 / 60), 2);
    });

    test('a frame exactly on the budget is not over', () {
      expect(framesOver([10000], 10), 0);
    });

    test('is zero for no frames', () {
      expect(framesOver([], 8.3), 0);
    });
  });

  group('the summary', () {
    final report = {
      'meta': _meta(),
      'retail/scan-in-app/1': _run(frames: 590, buildAvg: 1, rasterAvg: 2),
      'retail/scan-in-app/2': _run(frames: 600, buildAvg: 3, rasterAvg: 4),
      'retail/scan-in-app/3': _run(
        frames: 610,
        buildAvg: 2,
        rasterAvg: 9,
        buildTimes: [10000, 20000, 30000],
        rasterTimes: [10000, 17000, 18000, 19000],
      ),
      'utility/scan-alone/1': _run(frames: 600, buildAvg: 0.5, rasterAvg: 1),
    };
    final summary = ScanPerformanceSummary.fromReport(report);

    test('groups the repeats of one brand and variant', () {
      expect(summary.variants.map((v) => '${v.brand}/${v.variant}'), [
        'retail/scan-in-app',
        'utility/scan-alone',
      ]);
      expect(summary.variants.first.repeats, 3);
    });

    test('takes the median of each statistic over the repeats', () {
      final v = summary.variants.first;
      expect(v.buildAvg, 2);
      expect(v.buildP90, 4);
      expect(v.buildWorst, 8);
      expect(v.rasterAvg, 4);
      expect(v.rasterP90, 8);
      expect(v.rasterWorst, 16);
      expect(v.frames, 600);
    });

    test('derives the frame rate from the frames and the window', () {
      expect(summary.variants.first.fps, 60);
    });

    test('counts the frames over the display budget, median over repeats', () {
      final v = summary.variants.first;
      // Runs: 0 over, 0 over, and 2 (30 ms, 20 ms) over by build; the median is 0.
      expect(v.buildOverBudget, 0);
      expect(v.rasterOverBudget, 0);
    });

    test('counts them per run before taking the median', () {
      final allSlow = ScanPerformanceSummary.fromReport({
        'meta': _meta(),
        for (var i = 1; i <= 3; i++)
          'retail/scan-in-app/$i': _run(
            frames: 600,
            buildAvg: 1,
            rasterAvg: 1,
            buildTimes: [30000, 40000, 1000],
            rasterTimes: [1000, 25000],
          ),
      });
      expect(allSlow.variants.single.buildOverBudget, 2);
      expect(allSlow.variants.single.rasterOverBudget, 1);
    });

    test('judges against the budget of the display it ran on', () {
      final fast = ScanPerformanceSummary.fromReport({
        'meta': {..._meta(), 'refreshRate': 120.0, 'budgetMs': 1000 / 120},
        'retail/scan-in-app/1': _run(
          frames: 1200,
          buildAvg: 1,
          rasterAvg: 1,
          buildTimes: [9000, 7000],
          rasterTimes: [7000],
        ),
      });
      expect(fast.variants.single.buildOverBudget, 1, reason: '9 ms > 8.33 ms');
    });

    test('reports the median garbage collections', () {
      expect(summary.variants.first.newGenGc, 2);
    });

    test('rejects an entry that is not a run', () {
      expect(
        () => ScanPerformanceSummary.fromReport({
          'meta': _meta(),
          'whatever': _run(frames: 1, buildAvg: 1, rasterAvg: 1),
        }),
        throwsFormatException,
      );
    });
  });

  group('the table', () {
    test('has a row per brand and variant, with the numbers in it', () {
      final table = ScanPerformanceSummary.fromReport({
        'meta': _meta(),
        'retail/scan-in-app/1': _run(
          frames: 600,
          buildAvg: 1.234,
          rasterAvg: 2,
        ),
      }).toMarkdown();

      expect(table, contains('| retail | scan-in-app | 60.0 |'));
      expect(table, contains('1.23 / 2.47 / 4.94'));
      expect(table, contains('Test device'));
      expect(table, isNot(contains('NOT profile')));
    });

    test('says so when the run was not in profile mode', () {
      final table = ScanPerformanceSummary.fromReport({
        'meta': _meta(mode: 'debug'),
        'retail/scan-in-app/1': _run(frames: 600, buildAvg: 1, rasterAvg: 1),
      }).toMarkdown();

      expect(table, contains('NOT profile'));
    });

    test('serialises every statistic', () {
      final json = ScanPerformanceSummary.fromReport({
        'meta': _meta(),
        'retail/scan-in-app/1': _run(frames: 600, buildAvg: 1, rasterAvg: 1),
      }).toJson();

      final variant = (json['variants']! as List).single as Map;
      expect(
        variant.keys,
        containsAll([
          'build_avg_ms',
          'build_p90_ms',
          'build_worst_ms',
          'raster_avg_ms',
          'raster_p90_ms',
          'raster_worst_ms',
          'fps',
        ]),
      );
    });
  });
}
