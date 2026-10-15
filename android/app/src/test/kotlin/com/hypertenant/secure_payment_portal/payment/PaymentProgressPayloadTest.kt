package com.hypertenant.secure_payment_portal.payment

import org.junit.Assert.assertEquals
import org.junit.Test

class PaymentProgressPayloadTest {
    @Test
    fun idleHasOnlyTheState() {
        assertEquals(
            mapOf("schemaVersion" to 1, "state" to "idle"),
            PaymentProgressPayload.of(PaymentProgress.Idle),
        )
    }

    @Test
    fun runningCarriesItsPaymentAndPercent() {
        assertEquals(
            mapOf("schemaVersion" to 1, "state" to "running", "paymentId" to "bill-1", "percent" to 35),
            PaymentProgressPayload.of(PaymentProgress.Running("bill-1", 35)),
        )
    }

    @Test
    fun succeededCarriesTheReceipt() {
        assertEquals(
            mapOf(
                "schemaVersion" to 1,
                "state" to "succeeded",
                "paymentId" to "bill-1",
                "transactionId" to "TX-9",
                "amountMinor" to 1100L,
                "currency" to "USD",
                "completedAtMillis" to 1_700_000_000_000L,
            ),
            PaymentProgressPayload.of(
                PaymentProgress.Succeeded("bill-1", "TX-9", 1100, "USD", 1_700_000_000_000L)
            ),
        )
    }

    @Test
    fun failedCarriesTheCode() {
        assertEquals(
            mapOf("schemaVersion" to 1, "state" to "failed", "errorCode" to "declined"),
            PaymentProgressPayload.of(PaymentProgress.Failed("declined")),
        )
    }

    @Test
    fun cancelledHasOnlyTheState() {
        assertEquals(
            mapOf("schemaVersion" to 1, "state" to "cancelled"),
            PaymentProgressPayload.of(PaymentProgress.Cancelled),
        )
    }

    @Test
    fun noStateCarriesAnotherStatesFields() {
        val running = PaymentProgressPayload.of(PaymentProgress.Running("a", 1)).keys
        val cancelled = PaymentProgressPayload.of(PaymentProgress.Cancelled).keys

        assertEquals(setOf("schemaVersion", "state", "paymentId", "percent"), running)
        assertEquals(setOf("schemaVersion", "state"), cancelled)
    }
}
