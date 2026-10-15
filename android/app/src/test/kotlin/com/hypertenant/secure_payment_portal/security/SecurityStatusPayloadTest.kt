package com.hypertenant.secure_payment_portal.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class SecurityStatusPayloadTest {
    @Test
    fun theStatusReplyHasTheDocumentedShape() {
        val payload =
            SecurityStatusPayload.status(
                root = RootReport(Detection.DETECTED, listOf("su_binary", "test_keys")),
                recording = Detection.UNKNOWN,
                window = WindowProtection.ACTIVE,
            )

        assertEquals(
            mapOf(
                "schemaVersion" to 1,
                "root" to "detected",
                "rootSignals" to listOf("su_binary", "test_keys"),
                "screenRecording" to "unknown",
                "windowProtection" to "active",
            ),
            payload,
        )
    }

    @Test
    fun aCleanDeviceHasNoSignals() {
        val payload =
            SecurityStatusPayload.status(
                RootReport(Detection.NOT_DETECTED, emptyList()),
                Detection.NOT_DETECTED,
                WindowProtection.INACTIVE,
            )

        assertEquals("notDetected", payload["root"])
        assertEquals(emptyList<String>(), payload["rootSignals"])
        assertEquals("inactive", payload["windowProtection"])
    }

    @Test
    fun aRecordingEventHasTheDocumentedShape() {
        assertEquals(
            mapOf("schemaVersion" to 1, "screenRecording" to "detected"),
            SecurityStatusPayload.recording(Detection.DETECTED),
        )
    }

    @Test
    fun everyDetectionHasItsWireValue() {
        assertEquals(
            listOf("detected", "notDetected", "unknown"),
            Detection.entries.map { it.wire },
        )
        assertEquals(
            listOf("active", "inactive", "unknown"),
            WindowProtection.entries.map { it.wire },
        )
    }

    // The contract: signals are present exactly when root is detected. Dart rejects a payload that
    // breaks it, so the type must make it impossible to build one.
    @Test
    fun aReportThatBreaksTheSignalsRuleCannotBeBuilt() {
        assertThrows(IllegalArgumentException::class.java) {
            RootReport(Detection.DETECTED, emptyList())
        }
        assertThrows(IllegalArgumentException::class.java) {
            RootReport(Detection.NOT_DETECTED, listOf("su_binary"))
        }
        assertThrows(IllegalArgumentException::class.java) {
            RootReport(Detection.UNKNOWN, listOf("su_binary"))
        }
    }
}
