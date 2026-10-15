package com.hypertenant.secure_payment_portal.payment

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PaymentCancelActionTest {
    private val store = PaymentProgressStore()
    private val action = PaymentCancelAction(store)

    @Test
    fun theCancelActionCancelsARunningPayment() {
        store.tryStart(PaymentRequest("bill-1", 100, "USD"))

        assertTrue(action.handle(PaymentCancelAction.ACTION_CANCEL))

        assertEquals(PaymentProgress.Cancelled, store.state.value)
    }

    @Test
    fun withNothingRunningItDoesNothing() {
        assertFalse(action.handle(PaymentCancelAction.ACTION_CANCEL))
        assertEquals(PaymentProgress.Idle, store.state.value)
    }

    @Test
    fun anyOtherActionIsIgnored() {
        store.tryStart(PaymentRequest("bill-1", 100, "USD"))

        assertFalse(action.handle("android.intent.action.VIEW"))
        assertFalse(action.handle(null))

        assertTrue(store.state.value is PaymentProgress.Running)
    }
}
