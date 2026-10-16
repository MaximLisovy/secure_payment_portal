import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app draws Flutter's performance overlay: the frame graphs of the
/// UI and raster threads, for a demo recording or a look at a profile build. Off
/// by default; the demo panel (never present in release) is the only way to turn
/// it on.
final showPerformanceOverlayProvider =
    NotifierProvider<PerformanceOverlayNotifier, bool>(
      PerformanceOverlayNotifier.new,
    );

class PerformanceOverlayNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set({required bool visible}) => state = visible;
}
