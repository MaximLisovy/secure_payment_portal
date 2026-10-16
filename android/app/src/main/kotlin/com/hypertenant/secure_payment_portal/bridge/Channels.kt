package com.hypertenant.secure_payment_portal.bridge

// Kotlin mirror of lib/core/platform/channel_contract.dart. Every name, key and code exists once on
// each side, with the same object name and the same value; the table in docs/platform_channels.md
// documents them. A Dart test (test/core/platform/channel_contract_sync_test.dart) compares the two
// files, so a change on one side that is not made on the other fails the build.
//
// Channel names never depend on the applicationId, which differs per flavor.

object ChannelContract {
    const val NAMESPACE = "com.hypertenant.secure_payment_portal"

    /** Bumped when a payload changes incompatibly. A reader rejects any other. */
    const val SCHEMA_VERSION = 2
    const val KEY_SCHEMA_VERSION = "schemaVersion"
}

/** Error codes a MethodChannel call may fail with (`PlatformException.code` in Dart). */
object ChannelErrorCodes {
    const val INVALID_ARGS = "INVALID_ARGS"
    const val UNAVAILABLE = "UNAVAILABLE"
    const val INTERNAL = "INTERNAL"

    /** `startPayment` while a payment is already running. */
    const val ALREADY_RUNNING = "ALREADY_RUNNING"

    /** The OS refused to start the foreground service (background start limits). */
    const val START_NOT_ALLOWED = "START_NOT_ALLOWED"
}

/** Wire values of a tri-state fact. */
object DetectionWire {
    const val DETECTED = "detected"
    const val NOT_DETECTED = "notDetected"
    const val UNKNOWN = "unknown"
}

/** Wire values of whether the app window is currently hidden from capture. */
object WindowProtectionWire {
    const val ACTIVE = "active"
    const val INACTIVE = "inactive"
    const val UNKNOWN = "unknown"
}

/** Wire values of the reply to `requestNotificationPermission`. */
object NotificationPermissionWire {
    const val GRANTED = "granted"
    const val DENIED = "denied"

    /** Below API 33 there is no permission to ask for. */
    const val NOT_REQUIRED = "notRequired"
}

/** Reason codes of the independent root heuristics (`rootSignals`). */
object RootReasonCodes {
    const val SU_BINARY = "su_binary"
    const val MAGISK_ARTIFACTS = "magisk_artifacts"
    const val ROOT_MANAGER_PACKAGE = "root_manager_package"
    const val WHICH_SU = "which_su"
    const val TEST_KEYS = "test_keys"
    const val DEBUGGABLE_BUILD = "debuggable_build"
}

object SecurityChannel {
    /** `MethodChannel`: `getSecurityStatus`, `enableSecureWindow`, `disableSecureWindow`. */
    const val METHODS = "${ChannelContract.NAMESPACE}/security"

    /** `EventChannel`: screen recording changes. Emits the current value on listen. */
    const val RECORDING_EVENTS = "${ChannelContract.NAMESPACE}/security/screen_recording"

    const val GET_SECURITY_STATUS = "getSecurityStatus"
    const val ENABLE_SECURE_WINDOW = "enableSecureWindow"
    const val DISABLE_SECURE_WINDOW = "disableSecureWindow"

    const val KEY_ROOT = "root"
    const val KEY_ROOT_SIGNALS = "rootSignals"
    const val KEY_SCREEN_RECORDING = "screenRecording"
    const val KEY_WINDOW_PROTECTION = "windowProtection"
}

object PaymentChannel {
    /** `MethodChannel`: `startPayment`, `cancelPayment`. */
    const val METHODS = "${ChannelContract.NAMESPACE}/payment"

    /**
     * `EventChannel`: payment progress. Emits the current state on listen, and terminal states stay
     * current until the next `startPayment`.
     */
    const val PROGRESS_EVENTS = "${ChannelContract.NAMESPACE}/payment/progress"

    const val START_PAYMENT = "startPayment"
    const val CANCEL_PAYMENT = "cancelPayment"
    const val GET_PAYMENT_SNAPSHOT = "getPaymentSnapshot"

    /**
     * Asks for the notification permission (a runtime permission from API 33) and replies with a
     * [NotificationPermissionWire] value. Never fails.
     */
    const val REQUEST_NOTIFICATION_PERMISSION = "requestNotificationPermission"

    const val KEY_ATTEMPT_ID = "attemptId"
    const val KEY_PAYMENT_ID = "paymentId"
    const val KEY_AMOUNT_MINOR = "amountMinor"
    const val KEY_CURRENCY = "currency"
    const val KEY_STATE = "state"
    const val KEY_PERCENT = "percent"
    const val KEY_TRANSACTION_ID = "transactionId"
    const val KEY_COMPLETED_AT_MILLIS = "completedAtMillis"
    const val KEY_ERROR_CODE = "errorCode"

    const val STATE_IDLE = "idle"
    const val STATE_RUNNING = "running"
    const val STATE_SUCCEEDED = "succeeded"
    const val STATE_FAILED = "failed"
    const val STATE_CANCELLED = "cancelled"

    /** Values of `errorCode` in a `failed` event. */
    const val FAILURE_DECLINED = "declined"
    const val FAILURE_PROCESSING = "processing_failed"
}
