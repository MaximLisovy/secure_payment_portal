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
                "schemaVersion" to 2,
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
    fun unknownConfidenceRetainsObservedWeakSignals() {
        val payload = SecurityStatusPayload.status(
            RootReport(Detection.UNKNOWN, listOf("test_keys")), Detection.UNKNOWN, WindowProtection.ACTIVE,
        )
        assertEquals("unknown", payload["root"])
        assertEquals(listOf("test_keys"), payload["rootSignals"])
    }

    @Test
    fun aRecordingEventHasTheDocumentedShape() {
        assertEquals(
            mapOf("schemaVersion" to 2, "screenRecording" to "detected"),
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

    // Confidence is independent of signals; only clear/detected constrain their presence.
    @Test
    fun aReportThatBreaksTheSignalsRuleCannotBeBuilt() {
        assertThrows(IllegalArgumentException::class.java) {
            RootReport(Detection.DETECTED, emptyList())
        }
        assertThrows(IllegalArgumentException::class.java) {
            RootReport(Detection.NOT_DETECTED, listOf("su_binary"))
        }

    }
}
