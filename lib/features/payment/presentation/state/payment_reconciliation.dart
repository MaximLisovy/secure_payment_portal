import 'dart:async';

import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_repository.dart';

// Covers native processing (21 × 400 ms = 8.4 s) plus transport margin,
// while remaining well below the Android shortService limit of about 3 minutes.
const paymentReconciliationWindow = Duration(seconds: 30);

/// Queries immediately and with capped exponential backoff, independently of
/// stream delivery. Stopping invalidates an in-flight reply as well as timers.
final class PaymentReconciliation {
  Timer? _deadline;
  Timer? _next;
  int _generation = 0;

  void start({
    required PaymentRepository repository,
    required String attemptId,
    required void Function(PaymentProgress) onProgress,
    required void Function() onExpired,
  }) {
    stop();
    final generation = _generation;
    var delay = const Duration(milliseconds: 250);
    _deadline = Timer(paymentReconciliationWindow, () {
      stop();
      onExpired();
    });

    Future<void> query() async {
      final result = await repository.getPaymentSnapshot(attemptId: attemptId);
      if (generation != _generation) return;
      if (result case Success<PaymentProgress>(:final value)) {
        onProgress(value);
      }
      if (generation != _generation) return;
      _next = Timer(delay, () => unawaited(query()));
      delay = Duration(
        milliseconds: (delay.inMilliseconds * 2).clamp(250, 2000),
      );
    }

    unawaited(query());
  }

  void stop() {
    _generation++;
    _deadline?.cancel();
    _next?.cancel();
    _deadline = null;
    _next = null;
  }
}
