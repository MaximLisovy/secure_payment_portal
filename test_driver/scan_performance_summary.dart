/// Turns what `scan_performance_test.dart` reports into the numbers a person
/// reads: per brand and variant, the median over the repeats of the average,
/// 90th percentile and worst build and raster time, how many frames went over
/// the display's budget, and the frame rate actually delivered.
///
/// Plain Dart on plain maps, so it runs in the driver and is unit tested.
library;

/// The median of [values]; the mean of the middle two for an even count.
double median(List<double> values) {
  if (values.isEmpty) throw ArgumentError.value(values, 'values', 'is empty');
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

/// How many of [micros] (frame times in microseconds) are over [budgetMs].
int framesOver(List<int> micros, double budgetMs) =>
    micros.where((t) => t / 1000 > budgetMs).length;

/// One variant of one brand, aggregated over its repeats.
final class VariantStats {
  const VariantStats({
    required this.brand,
    required this.variant,
    required this.repeats,
    required this.frames,
    required this.fps,
    required this.buildAvg,
    required this.buildP90,
    required this.buildWorst,
    required this.rasterAvg,
    required this.rasterP90,
    required this.rasterWorst,
    required this.buildOverBudget,
    required this.rasterOverBudget,
    required this.newGenGc,
  });

  final String brand;
  final String variant;
  final int repeats;
  final double frames;
  final double fps;
  final double buildAvg;
  final double buildP90;
  final double buildWorst;
  final double rasterAvg;
  final double rasterP90;
  final double rasterWorst;
  final double buildOverBudget;
  final double rasterOverBudget;
  final double newGenGc;

  Map<String, Object> toJson() => {
    'brand': brand,
    'variant': variant,
    'repeats': repeats,
    'frames': frames,
    'fps': fps,
    'build_avg_ms': buildAvg,
    'build_p90_ms': buildP90,
    'build_worst_ms': buildWorst,
    'raster_avg_ms': rasterAvg,
    'raster_p90_ms': rasterP90,
    'raster_worst_ms': rasterWorst,
    'build_over_budget': buildOverBudget,
    'raster_over_budget': rasterOverBudget,
    'new_gen_gc': newGenGc,
  };
}

final class ScanPerformanceSummary {
  const ScanPerformanceSummary({required this.meta, required this.variants});

  /// Reads a report whose `meta` entry describes the run and whose other
  /// entries are `FrameTimingSummarizer` summaries keyed `brand/variant/repeat`.
  factory ScanPerformanceSummary.fromReport(Map<String, dynamic> report) {
    final meta = Map<String, dynamic>.from(report['meta'] as Map);
    final budgetMs = (meta['budgetMs'] as num).toDouble();
    final windowSeconds = (meta['windowSeconds'] as num).toDouble();

    final runs = <(String, String), List<Map<String, dynamic>>>{};
    for (final entry in report.entries) {
      if (entry.key == 'meta') continue;
      final parts = entry.key.split('/');
      if (parts.length != 3) {
        throw FormatException('Not a run key: "${entry.key}"');
      }
      runs
          .putIfAbsent((parts[0], parts[1]), () => [])
          .add(Map<String, dynamic>.from(entry.value as Map));
    }

    double med(List<Map<String, dynamic>> list, String key) =>
        median([for (final run in list) (run[key] as num).toDouble()]);

    List<int> micros(Map<String, dynamic> run, String key) => [
      for (final t in run[key] as List) (t as num).toInt(),
    ];

    final variants =
        [
          for (final MapEntry(key: (brand, variant), value: list)
              in runs.entries)
            VariantStats(
              brand: brand,
              variant: variant,
              repeats: list.length,
              frames: med(list, 'frame_count'),
              fps: median([
                for (final run in list)
                  (run['frame_count'] as num) / windowSeconds,
              ]),
              buildAvg: med(list, 'average_frame_build_time_millis'),
              buildP90: med(list, '90th_percentile_frame_build_time_millis'),
              buildWorst: med(list, 'worst_frame_build_time_millis'),
              rasterAvg: med(list, 'average_frame_rasterizer_time_millis'),
              rasterP90: med(
                list,
                '90th_percentile_frame_rasterizer_time_millis',
              ),
              rasterWorst: med(list, 'worst_frame_rasterizer_time_millis'),
              buildOverBudget: median([
                for (final run in list)
                  framesOver(
                    micros(run, 'frame_build_times'),
                    budgetMs,
                  ).toDouble(),
              ]),
              rasterOverBudget: median([
                for (final run in list)
                  framesOver(
                    micros(run, 'frame_rasterizer_times'),
                    budgetMs,
                  ).toDouble(),
              ]),
              newGenGc: med(list, 'new_gen_gc_count'),
            ),
        ]..sort(
          (a, b) =>
              '${a.brand}/${a.variant}'.compareTo('${b.brand}/${b.variant}'),
        );
    return ScanPerformanceSummary(meta: meta, variants: variants);
  }

  final Map<String, dynamic> meta;
  final List<VariantStats> variants;

  Map<String, Object> toJson() => {
    'meta': meta,
    'variants': [for (final v in variants) v.toJson()],
  };

  /// A table for a report: one row per brand and variant.
  String toMarkdown() {
    String ms(double value) => value.toStringAsFixed(2);
    final budget = (meta['budgetMs'] as num).toDouble();
    final mode = meta['mode'];
    final buffer = StringBuffer()
      ..writeln(
        'Device: ${meta['device']}. Build mode: $mode'
        '${mode == 'profile' ? '' : ' (NOT profile: these numbers are not representative)'}. '
        'Display: ${(meta['refreshRate'] as num).toStringAsFixed(1)} Hz, '
        'budget ${ms(budget)} ms per frame.',
      )
      ..writeln(
        '${meta['windowSeconds']} s recorded per run after a warm-up, '
        'median of ${variants.isEmpty ? 0 : variants.first.repeats} runs. '
        'Times in ms: average / 90th percentile / worst.',
      )
      ..writeln()
      ..writeln(
        '| Brand | Variant | FPS | Build (ms) | Raster (ms) | Over budget (build / raster) | GC (new gen) |',
      )
      ..writeln('|---|---|---|---|---|---|---|');
    for (final v in variants) {
      buffer.writeln(
        '| ${v.brand} | ${v.variant} | ${v.fps.toStringAsFixed(1)} '
        '| ${ms(v.buildAvg)} / ${ms(v.buildP90)} / ${ms(v.buildWorst)} '
        '| ${ms(v.rasterAvg)} / ${ms(v.rasterP90)} / ${ms(v.rasterWorst)} '
        '| ${v.buildOverBudget.round()} / ${v.rasterOverBudget.round()} '
        '| ${v.newGenGc.round()} |',
      );
    }
    return buffer.toString();
  }
}
