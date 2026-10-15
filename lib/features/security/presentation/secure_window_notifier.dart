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

  /// Tries again after a failure, while some screen still needs protection.
  Future<void> retry() async {
    if (_holders > 0 && !_enabled) await _enable();
  }

  Future<void> _enable() async {
    final result = await ref.read(secureWindowControllerProvider).enable();
    if (!ref.mounted) return;
    switch (result) {
      case Success<void>():
        _enabled = true;
        state = const SecureWindowProtected();
        // Every screen left while the platform was still answering.
        if (_holders == 0) await _disable();
      case Err<void>(:final failure):
        state = SecureWindowFailed(failure);
    }
  }

  Future<void> _disable() async {
    if (_enabled) {
      _enabled = false;
      // If this fails the window simply stays protected, which is the safe side.
      await ref.read(secureWindowControllerProvider).disable();
    }
    if (ref.mounted) state = const SecureWindowIdle();
  }
}
