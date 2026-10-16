// Dart mirror of the Kotlin `bridge/Channels.kt`. Draft v1: only this side
// exists until the native milestones; docs/platform_channels.md is the shared
// reference. Change both sides and that document in the same commit.
//
// Payloads are flat maps of primitives with explicit keys and a `schemaVersion`.
// Channel names never depend on the applicationId, which differs per flavor.

abstract final class ChannelContract {
  static const String namespace = 'com.hypertenant.secure_payment_portal';

  /// Bumped when a payload changes incompatibly. A reader rejects any other.
  static const int schemaVersion = 2;
  static const String keySchemaVersion = 'schemaVersion';
}

/// Error codes a `MethodChannel` call may fail with (`PlatformException.code`).
abstract final class ChannelErrorCodes {
  static const String invalidArgs = 'INVALID_ARGS';
  static const String unavailable = 'UNAVAILABLE';
  static const String internal = 'INTERNAL';

  /// `startPayment` while a payment is already running.
  static const String alreadyRunning = 'ALREADY_RUNNING';

  /// The OS refused to start the foreground service (background start limits).
  static const String startNotAllowed = 'START_NOT_ALLOWED';
}

/// Wire values of a tri-state fact.
abstract final class DetectionWire {
  static const String detected = 'detected';
  static const String notDetected = 'notDetected';
  static const String unknown = 'unknown';
}

/// Wire values of whether the app window is currently hidden from capture.
abstract final class WindowProtectionWire {
  static const String active = 'active';
  static const String inactive = 'inactive';
  static const String unknown = 'unknown';
}

/// Wire values of the reply to `requestNotificationPermission`.
abstract final class NotificationPermissionWire {
  static const String granted = 'granted';
  static const String denied = 'denied';

  /// Below API 33 there is no permission to ask for.
  static const String notRequired = 'notRequired';
}

/// Reason codes of the independent root heuristics (`rootSignals`).
abstract final class RootReasonCodes {
  static const String suBinary = 'su_binary';
  static const String magiskArtifacts = 'magisk_artifacts';
  static const String rootManagerPackage = 'root_manager_package';
  static const String whichSu = 'which_su';
  static const String testKeys = 'test_keys';
  static const String debuggableBuild = 'debuggable_build';
}

abstract final class SecurityChannel {
  /// `MethodChannel`: `getSecurityStatus`, `enableSecureWindow`, `disableSecureWindow`.
  static const String methods = '${ChannelContract.namespace}/security';

  /// `EventChannel`: screen recording changes. Emits the current value on listen.
  static const String recordingEvents =
      '${ChannelContract.namespace}/security/screen_recording';

  static const String getSecurityStatus = 'getSecurityStatus';
  static const String enableSecureWindow = 'enableSecureWindow';
  static const String disableSecureWindow = 'disableSecureWindow';

  static const String keyRoot = 'root';
  static const String keyRootSignals = 'rootSignals';
  static const String keyScreenRecording = 'screenRecording';
  static const String keyWindowProtection = 'windowProtection';
}

abstract final class PaymentChannel {
  /// `MethodChannel`: `startPayment`, `cancelPayment`.
  static const String methods = '${ChannelContract.namespace}/payment';

  /// `EventChannel`: payment progress. Emits the current state on listen, and
  /// terminal states stay current until the next `startPayment`.
  static const String progressEvents =
      '${ChannelContract.namespace}/payment/progress';

  static const String startPayment = 'startPayment';
  static const String cancelPayment = 'cancelPayment';
  static const String getPaymentSnapshot = 'getPaymentSnapshot';

  /// Asks for the notification permission (a runtime permission from API 33)
  /// and replies with a [NotificationPermissionWire] value. Never fails.
  static const String requestNotificationPermission =
      'requestNotificationPermission';

  static const String keyAttemptId = 'attemptId';
  static const String keyPaymentId = 'paymentId';
  static const String keyAmountMinor = 'amountMinor';
  static const String keyCurrency = 'currency';
  static const String keyState = 'state';
  static const String keyPercent = 'percent';
  static const String keyTransactionId = 'transactionId';
  static const String keyCompletedAtMillis = 'completedAtMillis';
  static const String keyErrorCode = 'errorCode';

  static const String stateIdle = 'idle';
  static const String stateRunning = 'running';
  static const String stateSucceeded = 'succeeded';
  static const String stateFailed = 'failed';
  static const String stateCancelled = 'cancelled';

  /// Values of `errorCode` in a `failed` event.
  static const String failureDeclined = 'declined';
  static const String failureProcessing = 'processing_failed';
}
