import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/features/security/di/security_providers.dart';
import 'package:secure_payment_portal/features/security/domain/secure_window_controller.dart';
import 'package:secure_payment_portal/features/security/presentation/secure_window_state.dart';

/// The one owner of the secure window in the app. Screens [acquire] and
/// [release] it; the platform is asked only on the first acquire and the last
/// release, so a second screen never unprotects the first.
///
/// App-scoped on purpose: screens come and go, the window does not.
final secureWindowProvider =
    NotifierProvider<SecureWindowNotifier, SecureWindowState>(
      SecureWindowNotifier.new,
    );

class SecureWindowNotifier extends Notifier<SecureWindowState> {
  int _holders = 0;

  /// The controller that turned protection on, while it is on. Releasing goes to
  /// this one, not to whatever the provider says now: a debug build can switch
  /// the security source under a visible screen.
  SecureWindowController? _enabledOn;

  @override
  SecureWindowState build() => const SecureWindowIdle();

  /// A screen that needs protection is showing.
  Future<void> acquire() async {
    _holders++;
    if (_holders == 1) await _enable();
  }

  /// A screen that needed protection is gone.
  Future<void> release() async {
    if (_holders == 0) return;
    _holders--;
    if (_holders > 0) return;
    await _disable();
  }

  /// Makes sure the window is protected on the *current* source, while some
  /// screen needs it: tries again after a failure, and moves the protection
  /// when the security source was switched since it was turned on.
  Future<void> retry() async {
    if (_holders == 0) return;
    final stale = _enabledOn;
    if (stale != null &&
        !identical(stale, ref.read(secureWindowControllerProvider))) {
      _enabledOn = null;
      await stale.disable();
      if (!ref.mounted) return;
    }
    if (_enabledOn == null) await _enable();
  }

  Future<void> _enable() async {
    final controller = ref.read(secureWindowControllerProvider);
    final result = await controller.enable();
    if (!ref.mounted) return;
    switch (result) {
      case Success<void>():
        _enabledOn = controller;
        state = const SecureWindowProtected();
        // Every screen left while the platform was still answering.
        if (_holders == 0) await _disable();
      case Err<void>(:final failure):
        state = SecureWindowFailed(failure);
    }
  }

  Future<void> _disable() async {
    final enabledOn = _enabledOn;
    if (enabledOn != null) {
      _enabledOn = null;
      // If this fails the window simply stays protected, which is the safe side.
      await enabledOn.disable();
    }
    if (ref.mounted) state = const SecureWindowIdle();
  }
}
