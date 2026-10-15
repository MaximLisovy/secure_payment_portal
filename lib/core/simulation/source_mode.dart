import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which implementation a controllable source runs on.
enum SourceMode { real, simulated }

/// The mode of one source: the real implementation when one is wired, otherwise
/// the simulation. Features declare one provider of this per source and select
/// the implementation from it.
///
/// A debug build may switch at runtime, to demo or test without a device or
/// backend. A release build cannot: the mode is whatever [build] chose, so a
/// shipped app never runs on a simulation by someone's tap.
class SourceModeNotifier extends Notifier<SourceMode> {
  SourceModeNotifier({required this.isRealAvailable, bool? canSwitch})
    : canSwitch = canSwitch ?? !kReleaseMode;

  /// Whether a real implementation is wired for this source.
  final bool Function(Ref ref) isRealAvailable;

  final bool canSwitch;

  bool get realAvailable => isRealAvailable(ref);

  @override
  SourceMode build() => realAvailable ? SourceMode.real : SourceMode.simulated;

  void select(SourceMode mode) {
    if (!canSwitch) {
      throw StateError('The source mode cannot be changed in a release build.');
    }
    if (mode == SourceMode.real && !realAvailable) {
      throw StateError('No real implementation is wired for this source.');
    }
    state = mode;
  }
}
