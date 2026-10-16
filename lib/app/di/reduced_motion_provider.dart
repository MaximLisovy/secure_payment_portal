import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the user asked the system to reduce motion. It is the flag
/// `MediaQuery.disableAnimationsOf` reads, kept up to date while the app runs,
/// for the code that has no `BuildContext` (a notifier choosing how long to wait).
final reducedMotionProvider = NotifierProvider<ReducedMotionNotifier, bool>(
  ReducedMotionNotifier.new,
);

class ReducedMotionNotifier extends Notifier<bool> with WidgetsBindingObserver {
  @override
  bool build() {
    final binding = WidgetsBinding.instance..addObserver(this);
    ref.onDispose(() => binding.removeObserver(this));
    return _read();
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (ref.mounted) state = _read();
  }

  bool _read() => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;
}
