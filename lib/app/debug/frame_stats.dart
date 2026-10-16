import 'dart:collection';

import 'package:equatable/equatable.dart';

// About five seconds at 120 Hz; bounded memory even during a long phone run.
const frameStatsWindowCapacity = 600;

final class FramePercentiles extends Equatable {
  const FramePercentiles(this.p50, this.p90, this.p99, this.worst);
  const FramePercentiles.empty() : this(0, 0, 0, 0);

  /// Milliseconds; nearest-rank percentiles computed separately per thread.
  final double p50;
  final double p90;
  final double p99;
  final double worst;

  @override
  List<Object?> get props => [p50, p90, p99, worst];
}

final class FrameStatsSnapshot extends Equatable {
  const FrameStatsSnapshot({
    this.totalFrames = 0,
    this.windowFrames = 0,
    this.build = const FramePercentiles.empty(),
    this.raster = const FramePercentiles.empty(),
  });

  final int totalFrames;
  final int windowFrames;
  final FramePercentiles build;
  final FramePercentiles raster;

  @override
  List<Object?> get props => [totalFrames, windowFrames, build, raster];
}

/// Bounded rolling samples, independent of Flutter and its delivery batching.
final class FrameStatsWindow {
  FrameStatsWindow({this.capacity = frameStatsWindowCapacity})
    : assert(capacity > 0);

  final int capacity;
  final _samples = ListQueue<({int build, int raster})>();
  int _totalFrames = 0;

  void add({required Duration build, required Duration raster}) {
    if (_samples.length == capacity) _samples.removeFirst();
    _samples.add((build: build.inMicroseconds, raster: raster.inMicroseconds));
    _totalFrames++;
  }

  void reset() {
    _samples.clear();
    _totalFrames = 0;
  }

  FrameStatsSnapshot snapshot() => FrameStatsSnapshot(
    totalFrames: _totalFrames,
    windowFrames: _samples.length,
    build: _percentiles(_samples.map((sample) => sample.build)),
    raster: _percentiles(_samples.map((sample) => sample.raster)),
  );

  static FramePercentiles _percentiles(Iterable<int> samples) {
    final sorted = samples.toList()..sort();
    if (sorted.isEmpty) return const FramePercentiles.empty();
    double at(double percentile) =>
        sorted[(sorted.length * percentile).ceil() - 1] / 1000;
    return FramePercentiles(at(0.50), at(0.90), at(0.99), sorted.last / 1000);
  }
}
