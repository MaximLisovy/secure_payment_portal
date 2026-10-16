import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';
import 'package:secure_payment_portal/features/security/presentation/secure_window_notifier.dart';
import 'package:secure_payment_portal/features/security/presentation/secure_window_state.dart';

/// Keeps the app window hidden from screenshots, the recents list and screen
/// recording for as long as [child] is on screen.
///
/// The child is mounted only after the platform confirms window protection.
/// Pending protection shows a neutral placeholder; failure shows a blocked
/// message. Protection stays acquired until disposal, including route animations.
class SecureScreen extends ConsumerStatefulWidget {
  const SecureScreen({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends ConsumerState<SecureScreen> {
  late final SecureWindowNotifier _window;

  @override
  void initState() {
    super.initState();
    _window = ref.read(secureWindowProvider.notifier);
    unawaited(_window.acquire());
  }

  @override
  void dispose() {
    unawaited(_window.release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final protection = ref.watch(secureWindowProvider);
    if (protection is SecureWindowProtected) return widget.child;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                protection is SecureWindowFailed
                    ? AppStrings.message(
                        'security.blocked.screen_protection_unavailable',
                      )
                    : AppStrings.protectingScreen,
                textAlign: TextAlign.center,
              ),
            ),
            if (protection is SecureWindowFailed)
              TextButton(
                onPressed: _window.retry,
                child: const Text(AppStrings.checkAgain),
              ),
          ],
        ),
      ),
    );
  }
}
