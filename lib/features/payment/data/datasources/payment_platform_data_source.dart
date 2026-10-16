import 'package:secure_payment_portal/features/payment/data/dtos/payment_progress_dto.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/start_payment_request_dto.dart';

/// Runs the payment processing. Today a fake simulates it; the channel-based
/// implementation, backed by a foreground service, replaces it unchanged. Both
/// honour this contract (the contract suite checks it).
///
/// Failures are thrown as `DataSourceException`s, never as platform types.
abstract interface class PaymentPlatformDataSource {
  /// Completes user interaction, such as the optional notification prompt.
  Future<void> preparePayment();

  /// Returns once processing was accepted, not once it finished.
  ///
  /// Throws `PlatformCallException(ALREADY_RUNNING)` while a payment is running
  /// and `PlatformCallException(INVALID_ARGS)` for an unusable request
  /// (a non-positive amount).
  Future<void> startPayment(StartPaymentRequestDto request);

  /// Cancels only the matching attempt and reports `cancelled`. A stale ID
  /// or nothing running is a successful no-op.
  Future<void> cancelPayment({required String attemptId});

  /// Emits the current state as soon as it is listened to (`idle` before any
  /// payment), then each change. A terminal state (`succeeded`, `failed`,
  /// `cancelled`) stays current until the next `startPayment`. Every listener
  /// gets that replay.
  Stream<PaymentProgressDto> watchProgress();

  /// Current retained state for this attempt. Idle is absence, not rejection:
  /// a delayed start may still arrive after this query.
  Future<PaymentProgressDto> getPaymentSnapshot({required String attemptId});
}
