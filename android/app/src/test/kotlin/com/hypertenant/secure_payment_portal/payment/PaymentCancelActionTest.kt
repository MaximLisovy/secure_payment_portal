package com.hypertenant.secure_payment_portal.payment

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PaymentCancelActionTest {
    private val store = PaymentProgressStore()
    private val action = PaymentCancelAction(store)

    @Test
    fun aStaleNotificationCannotCancelTheReplacementAttempt() {
        store.tryStart(PaymentRequest("bill-1", 100, "USD", "old"))
        action.handle(PaymentCancelAction.ACTION_CANCEL, "old")
        store.tryStart(PaymentRequest("bill-1", 100, "USD", "new"))
        assertFalse(action.handle(PaymentCancelAction.ACTION_CANCEL, "old"))
        assertEquals(PaymentProgress.Running("bill-1", 0, "new"), store.state.value)
        assertTrue(action.handle(PaymentCancelAction.ACTION_CANCEL, "new"))
    }

    @Test
    fun theCancelActionCancelsARunningPayment() {
        store.tryStart(PaymentRequest("bill-1", 100, "USD", "attempt-1"))

        assertTrue(action.handle(PaymentCancelAction.ACTION_CANCEL, "attempt-1"))

        assertEquals(PaymentProgress.Cancelled("bill-1", "attempt-1"), store.state.value)
    }

    @Test
    fun withNothingRunningItDoesNothing() {
        assertFalse(action.handle(PaymentCancelAction.ACTION_CANCEL, "attempt-1"))
        assertEquals(PaymentProgress.Idle, store.state.value)
    }

    @Test
    fun anyOtherActionIsIgnored() {
        store.tryStart(PaymentRequest("bill-1", 100, "USD", "attempt-1"))

        assertFalse(action.handle("android.intent.action.VIEW", "attempt-1"))
        assertFalse(action.handle(null, "attempt-1"))

        assertTrue(store.state.value is PaymentProgress.Running)
    }
}
