package com.hypertenant.secure_payment_portal.payment

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

private class NotAllowedHere : IllegalStateException("app is in the background")

class PaymentStarterTest {
    private val store = PaymentProgressStore()
    private val launched = mutableListOf<PaymentRequest>()
    private val request = PaymentRequest("bill-1", 1100, "USD")

    private fun starter(launcher: ServiceLauncher = ServiceLauncher { launched += it }) =
        PaymentStarter(store, launcher)

    @Test
    fun claimsThePaymentThenStartsTheServiceOnce() {
        val result = starter().start(request)

        assertEquals(StartResult.Accepted, result)
        assertEquals(listOf(request), launched)
        assertEquals(PaymentProgress.Running("bill-1", 0), store.state.value)
    }

    @Test
    fun theServiceSeesTheClaimWhenItIsStarted() {
        var seenByService: PaymentProgress? = null

        starter { seenByService = store.state.value }.start(request)

        assertEquals(PaymentProgress.Running("bill-1", 0), seenByService)
    }

    @Test
    fun aSecondStartWhileOneRunsIsRefusedWithoutStartingAnything() {
        starter().start(request)
        store.reportProgress("bill-1", 40)

        val second = starter().start(PaymentRequest("bill-2", 5, "EUR"))

        assertEquals(StartResult.AlreadyRunning, second)
        assertEquals(1, launched.size)
        assertEquals(PaymentProgress.Running("bill-1", 40), store.state.value)
    }

    @Test
    fun aRefusalByTheSystemIsNotAllowedAndTheClaimIsGivenBack() {
        val result = starter { throw NotAllowedHere() }.start(request)

        assertEquals(StartResult.NotAllowed, result)
        assertEquals(PaymentProgress.Idle, store.state.value)
        assertEquals("so the next try is not refused", StartResult.Accepted, starter().start(request))
    }

    @Test
    fun aRollbackRestoresWhatWasThereBeforeNotJustIdle() {
        starter().start(request)
        store.succeed("bill-1", "TX", 1100, "USD", 1L)
        val finished = store.state.value

        starter { throw NotAllowedHere() }.start(PaymentRequest("bill-2", 5, "USD"))

        assertEquals(finished, store.state.value)
    }

    @Test
    fun anyOtherFailureToStartIsFailedAndAlsoRolledBack() {
        val result = starter { throw SecurityException("missing permission") }.start(request)

        assertEquals(StartResult.Failed, result)
        assertEquals(PaymentProgress.Idle, store.state.value)
    }

    @Test
    fun aCancelThatWonWhileTheServiceWasBeingStartedStands() {
        val result =
            starter {
                    store.cancelIfRunning()
                    throw NotAllowedHere()
                }
                .start(request)

        assertEquals(StartResult.NotAllowed, result)
        assertEquals(PaymentProgress.Cancelled, store.state.value)
    }

    @Test
    fun theStartErrorsAreTold_byTheirKind() {
        assertEquals(StartResult.NotAllowed, ServiceStartErrors.resultFor(IllegalStateException()))
        assertEquals(StartResult.NotAllowed, ServiceStartErrors.resultFor(NotAllowedHere()))
        assertEquals(StartResult.Failed, ServiceStartErrors.resultFor(SecurityException()))
        assertEquals(StartResult.Failed, ServiceStartErrors.resultFor(RuntimeException()))
        assertTrue(ServiceStartErrors.resultFor(IllegalArgumentException()) == StartResult.Failed)
    }
}
