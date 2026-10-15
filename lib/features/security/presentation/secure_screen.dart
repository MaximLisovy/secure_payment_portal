import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/features/security/presentation/secure_window_notifier.dart';

/// Keeps the app window hidden from screenshots, the recents list and screen
/// recording for as long as [child] is on screen.
///
/// It protects from the first build until it is disposed, not until the route is
/// covered. A page that is popped stays protected through its pop animation, and
/// one that another route is pushed over stays protected while that route slides
/// in, so there is no moment when a sensitive page is visible and unprotected.
/// Protection that outlives its visibility costs nothing.
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
  Widget build(BuildContext context) => widget.child;
}
