package com.hypertenant.secure_payment_portal.security

import com.hypertenant.secure_payment_portal.bridge.DetectionWire
import com.hypertenant.secure_payment_portal.bridge.WindowProtectionWire

/**
 * A platform fact that may be impossible to know. "Can't tell" is its own value and is never
 * collapsed into [NOT_DETECTED].
 */
enum class Detection(val wire: String) {
    DETECTED(DetectionWire.DETECTED),
    NOT_DETECTED(DetectionWire.NOT_DETECTED),
    UNKNOWN(DetectionWire.UNKNOWN),
}

/** Whether the app window is hidden from capture right now. */
enum class WindowProtection(val wire: String) {
    ACTIVE(WindowProtectionWire.ACTIVE),
    INACTIVE(WindowProtectionWire.INACTIVE),
    UNKNOWN(WindowProtectionWire.UNKNOWN),
}
