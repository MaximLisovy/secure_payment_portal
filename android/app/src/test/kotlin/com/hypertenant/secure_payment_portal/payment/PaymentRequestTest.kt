package com.hypertenant.secure_payment_portal.payment

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PaymentRequestTest {
    private fun args(
        schemaVersion: Any? = 2,
        paymentId: Any? = "bill-1",
        amountMinor: Any? = 1100,
        currency: Any? = "USD",
    ) =
        mapOf(
            "schemaVersion" to schemaVersion,
            "paymentId" to paymentId,
            "attemptId" to "attempt-1",
            "amountMinor" to amountMinor,
            "currency" to currency,
        )

    @Test
    fun readsTheDocumentedArguments() {
        assertEquals(PaymentRequest("bill-1", 1100, "USD", "attempt-1"), PaymentRequest.fromArguments(args()))
    }

    @Test
    fun aDartIntMayArriveAsAnIntOrALong() {
        assertEquals(
            PaymentRequest("bill-1", 5_000_000_000, "USD", "attempt-1"),
            PaymentRequest.fromArguments(args(amountMinor = 5_000_000_000)),
        )
        assertEquals(1100L, PaymentRequest.fromArguments(args(amountMinor = 1100))!!.amountMinor)
    }

    @Test
    fun anAmountThatIsNotPositiveIsInvalid() {
        for (amount in listOf(0, -5, Long.MIN_VALUE)) {
            assertNull("$amount", PaymentRequest.fromArguments(args(amountMinor = amount)))
        }
    }

    @Test
    fun anAmountThatIsNotAnIntegerIsInvalid() {
        for (amount in listOf(11.5, 1100.0f, "1100", null, true)) {
            assertNull("$amount", PaymentRequest.fromArguments(args(amountMinor = amount)))
        }
    }

    @Test
    fun aMissingOrBlankIdOrCurrencyIsInvalid() {
        assertNull(PaymentRequest.fromArguments(args(paymentId = null)))
        assertNull(PaymentRequest.fromArguments(args(paymentId = "  ")))
        assertNull(PaymentRequest.fromArguments(args(paymentId = 7)))
        assertNull(PaymentRequest.fromArguments(args(currency = null)))
        assertNull(PaymentRequest.fromArguments(args(currency = "")))
    }

    @Test
    fun aMissingBlankOrWrongTypeAttemptIdIsInvalid() {
        assertNull(PaymentRequest.fromArguments(args() - "attemptId"))
        for (id in listOf(null, "", "  ", 7)) {
            assertNull(PaymentRequest.fromArguments(args() + ("attemptId" to id)))
        }
    }

    @Test
    fun anotherSchemaVersionIsInvalid() {
        assertNull(PaymentRequest.fromArguments(args(schemaVersion = 99)))
        assertNull(PaymentRequest.fromArguments(args(schemaVersion = null)))
    }

    @Test
    fun argumentsThatAreNotAMapAreInvalid() {
        assertNull(PaymentRequest.fromArguments(null))
        assertNull(PaymentRequest.fromArguments("bill-1"))
        assertNull(PaymentRequest.fromArguments(listOf(1, 2)))
        assertNull(PaymentRequest.fromArguments(emptyMap<String, Any>()))
    }

    @Test
    fun theIntentEntranceFollowsTheSameRule() {
        assertEquals(PaymentRequest("a", 1, "EUR", "attempt-1"), PaymentRequest.of("a", 1, "EUR", "attempt-1"))
        assertNull(PaymentRequest.of(null, 1, "EUR", "attempt-1"))
        assertNull(PaymentRequest.of("a", 0, "EUR", "attempt-1"))
        assertNull(PaymentRequest.of("a", 1, null, "attempt-1"))
    }
}
