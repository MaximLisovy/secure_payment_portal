import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/app/debug/frame_stats.dart';

final frameStatsProvider =
    NotifierProvider<FrameStatsNotifier, FrameStatsSnapshot>(
      FrameStatsNotifier.new,
    );

class FrameStatsNotifier extends Notifier<FrameStatsSnapshot> {
  final _window = FrameStatsWindow();

  @override
  FrameStatsSnapshot build() => const FrameStatsSnapshot();

  void record(List<FrameTiming> timings) {
    for (final frame in timings) {
      _window.add(build: frame.buildDuration, raster: frame.rasterDuration);
    }
  }

  void publish() => state = _window.snapshot();

  void reset() {
    _window.reset();
    publish();
  }
}

/// Mounted by App only outside release. Collection survives closing the panel;
/// only its small readout rebuilds, at most once per second, never per frame.
class FrameStatsCollector extends ConsumerStatefulWidget {
  const FrameStatsCollector({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<FrameStatsCollector> createState() =>
      _FrameStatsCollectorState();
}

class _FrameStatsCollectorState extends ConsumerState<FrameStatsCollector> {
  late final FrameStatsNotifier _stats;
  late final void Function(List<FrameTiming>) _callback;
  Timer? _publishTimer;

  @override
  void initState() {
    super.initState();
    _stats = ref.read(frameStatsProvider.notifier);
    _callback = _stats.record;
    SchedulerBinding.instance.addTimingsCallback(_callback);
    _publishTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _stats.publish(),
    );
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_callback);
    _publishTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
