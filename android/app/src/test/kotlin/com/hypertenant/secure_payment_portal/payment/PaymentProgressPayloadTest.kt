package com.hypertenant.secure_payment_portal.payment

import org.junit.Assert.assertEquals
import org.junit.Test

class PaymentProgressPayloadTest {
    @Test
    fun idleHasOnlyTheState() {
        assertEquals(
            mapOf("schemaVersion" to 2, "state" to "idle"),
            PaymentProgressPayload.of(PaymentProgress.Idle),
        )
    }

    @Test
    fun runningCarriesItsPaymentAndPercent() {
        assertEquals(
            mapOf("schemaVersion" to 2, "state" to "running", "paymentId" to "bill-1", "attemptId" to "attempt-1", "percent" to 35),
            PaymentProgressPayload.of(PaymentProgress.Running("bill-1", 35, "attempt-1")),
        )
    }

    @Test
    fun succeededCarriesTheReceipt() {
        assertEquals(
            mapOf(
                "schemaVersion" to 2,
                "state" to "succeeded",
                "paymentId" to "bill-1", "attemptId" to "attempt-1",
                "transactionId" to "TX-9",
                "amountMinor" to 1100L,
                "currency" to "USD",
                "completedAtMillis" to 1_700_000_000_000L,
            ),
            PaymentProgressPayload.of(
                PaymentProgress.Succeeded("bill-1", "TX-9", 1100, "USD", 1_700_000_000_000L, "attempt-1")
            ),
        )
    }

    @Test
    fun failedCarriesTheCode() {
        assertEquals(
            mapOf("schemaVersion" to 2, "state" to "failed", "paymentId" to "bill-1", "attemptId" to "attempt-1", "errorCode" to "declined"),
            PaymentProgressPayload.of(PaymentProgress.Failed("declined", "bill-1", "attempt-1")),
        )
    }

    @Test
    fun cancelledCarriesItsAttemptIdentity() {
        assertEquals(
            mapOf("schemaVersion" to 2, "state" to "cancelled", "paymentId" to "bill-1", "attemptId" to "attempt-1"),
            PaymentProgressPayload.of(PaymentProgress.Cancelled("bill-1", "attempt-1")),
        )
    }

    @Test
    fun noStateCarriesAnotherStatesFields() {
        val running = PaymentProgressPayload.of(PaymentProgress.Running("a", 1, "attempt-1")).keys
        val cancelled = PaymentProgressPayload.of(PaymentProgress.Cancelled("bill-1", "attempt-1")).keys

        assertEquals(setOf("schemaVersion", "state", "paymentId", "attemptId", "percent"), running)
        assertEquals(setOf("schemaVersion", "state", "paymentId", "attemptId"), cancelled)
    }
}
