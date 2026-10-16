import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/features/security/di/security_providers.dart';
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
  bool _enabled = false;

  /// The request for protection that the platform has not answered yet, if any.
  /// Set at once, with no provider write, because the first request comes from a
  /// widget's `initState`, where Riverpod forbids changing a provider.
  Future<void>? _request;

  @override
  SecureWindowState build() => const SecureWindowIdle();

  /// Completes once the platform has answered the latest request for protection,
  /// with success or with a failure: at once if none is in flight. Anything that
  /// reads whether the window is protected waits for this first, so that "not
  /// answered yet" is never mistaken for "protection failed".
  Future<void> settled() => _request ?? Future<void>.value();

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

  /// Tries again after a failure, while some screen still needs protection.
  Future<void> retry() async {
    if (_holders > 0 && !_enabled) await _enable();
  }

  Future<void> _enable() => _reconcile();

  Future<void> _disable() {
    // Leaving while enable is pending must not block disposal. The in-flight
    // reconciliation will balance the acquisition as soon as it succeeds.
    if (!_enabled && _request != null) return Future<void>.value();
    return _reconcile();
  }

  Future<void> _reconcile() {
    final pending = _request;
    if (pending != null) return pending;
    final request = _applyDesiredProtection();
    _request = request;
    return request.whenComplete(() {
      if (identical(_request, request)) _request = null;
    });
  }

  Future<void> _applyDesiredProtection() async {
    final controller = ref.read(secureWindowControllerProvider);
    while (ref.mounted) {
      final wanted = _holders > 0;
      if (wanted == _enabled) {
        await Future<void>.value();
        if (ref.mounted && (_holders > 0) == _enabled) {
          state = _enabled
              ? const SecureWindowProtected()
              : const SecureWindowIdle();
          return;
        }
        continue;
      }
      var answered = false;
      final answer = wanted ? controller.enable() : controller.disable();
      // The first acquisition runs from initState. Defer provider writes until
      // outside the widget lifecycle, while sending the native request at once.
      scheduleMicrotask(() {
        if (!answered && ref.mounted) state = const SecureWindowPending();
      });
      final result = await answer;
      answered = true;
      if (!ref.mounted) {
        if (wanted && result is Success<void>) await controller.disable();
        return;
      }
      switch (result) {
        case Success<void>():
          _enabled = wanted;
        case Err<void>(:final failure):
          // A failed disable retains our native claim. A later screen reuses
          // it instead of incrementing the platform's reference count again.
          state = SecureWindowFailed(failure);
          return;
      }
      // Holders may have changed during either command. Reconcile before
      // publishing a final state, so an old disable never marks a new screen idle.
      if ((_holders > 0) == _enabled) {
        state = _enabled
            ? const SecureWindowProtected()
            : const SecureWindowIdle();
        return;
      }
    }
  }
}
