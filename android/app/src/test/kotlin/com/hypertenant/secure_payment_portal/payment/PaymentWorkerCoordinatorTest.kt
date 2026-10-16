package com.hypertenant.secure_payment_portal.payment

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PaymentWorkerCoordinatorTest {
    private val first = PaymentRequest("bill", 100, "USD", "first")
    private val second = PaymentRequest("bill", 900, "USD", "second")
    private val store = PaymentProgressStore()

    @Test
    fun aCancelledAttemptCannotCompleteOrUpdateItsRetry() {
        store.tryStart(first)
        val claim = store.tryStart(second)
        assertEquals(StartClaim.AlreadyRunning, claim)
        store.cancelIfRunning(first.attemptId)
        store.tryStart(second)
        assertFalse(store.reportProgress(first.attemptId, 99))
        assertFalse(store.succeed(first.attemptId, "OLD", 100, "USD", 1))
        assertFalse(store.fail(first.attemptId, PaymentFailureCodes.PROCESSING))
        assertFalse(store.cancelIfRunning(first.attemptId))
        assertEquals(PaymentProgress.Running("bill", 0, "second"), store.state.value)
    }

    @Test
    fun anOldRollbackCannotRemoveTheNewClaimAtZeroPercent() {
        val claim = store.tryStart(first) as StartClaim.Accepted
        store.cancelIfRunning(first.attemptId)
        store.tryStart(second)
        store.rollback(claim)
        assertEquals(PaymentProgress.Running("bill", 0, "second"), store.state.value)
    }

    @Test
    fun rapidCancelAndRetryRunsTheReplacementAndOnlyItFinishesTheService() = runTest {
        val started = mutableListOf<String>()
        val completed = mutableListOf<Pair<Int, PaymentProgress>>()
        val coordinator = PaymentWorkerCoordinator(this, store, { request ->
            started += request.attemptId
            PaymentSession(store, SimulatedPaymentProcessor(2, 100) { request.attemptId }).run(request)
        }, { id, state -> completed += id to state })
        store.tryStart(first)
        coordinator.start(first, 1)
        runCurrent()
        store.cancelIfRunning(first.attemptId)
        store.tryStart(second)
        assertTrue(coordinator.start(second, 2))
        advanceUntilIdle()
        assertEquals(listOf("first", "second"), started)
        assertEquals(listOf(2), completed.map { it.first })
        val receipt = completed.single().second as PaymentProgress.Succeeded
        assertEquals("second", receipt.attemptId)
        assertEquals(900L, receipt.amountMinor)
    }

    @Test
    fun aDuplicateDeliveryRunsOnceAndStopsWithTheLatestStartId() = runTest {
        val stopped = mutableListOf<Int>()
        var starts = 0
        val coordinator = PaymentWorkerCoordinator(this, store, { request ->
            starts++
            PaymentSession(store, SimulatedPaymentProcessor(1, 100)).run(request)
        }, { id, _ -> stopped += id })
        store.tryStart(first)
        coordinator.start(first, 1)
        runCurrent()
        coordinator.start(first, 3)
        advanceUntilIdle()
        assertEquals(1, starts)
        assertEquals(listOf(3), stopped)
    }

    @Test
    fun obsoleteDeliveryStillAdvancesTheStartIdUsedToStopTheService() = runTest {
        val stopped = mutableListOf<Int>()
        val coordinator = PaymentWorkerCoordinator(this, store, { request ->
            PaymentSession(store, SimulatedPaymentProcessor(1, 100)).run(request)
        }, { id, _ -> stopped += id })
        store.tryStart(first)
        coordinator.start(first, 1)
        runCurrent()
        coordinator.observeDelivery(7)
        assertFalse(coordinator.start(second, 7))
        advanceUntilIdle()
        assertEquals(listOf(7), stopped)
    }

    @Test
    fun anOldWorkerDoesNotStopAReplacementAwaitingItsIntent() = runTest {
        val finished = mutableListOf<Int>()
        val release = CompletableDeferred<Unit>()
        val coordinator = PaymentWorkerCoordinator(this, store, { release.await() }, { id, _ -> finished += id })
        store.tryStart(first)
        coordinator.start(first, 1)
        runCurrent()
        store.cancelIfRunning(first.attemptId)
        store.tryStart(second)
        release.complete(Unit)
        runCurrent()
        assertTrue(finished.isEmpty())
        assertEquals(PaymentProgress.Running("bill", 0, "second"), store.state.value)
        coordinator.destroy()
    }

    @Test
    fun anOldTimeoutDoesNotStopAReplacementAwaitingItsIntent() = runTest {
        val completed = mutableListOf<Int>()
        val waiting = CompletableDeferred<Unit>()
        val coordinator = PaymentWorkerCoordinator(this, store, { waiting.await() }, { id, _ -> completed += id })
        store.tryStart(first)
        coordinator.start(first, 1)
        runCurrent()
        store.cancelIfRunning(first.attemptId)
        store.tryStart(second)
        coordinator.timeout(1)
        advanceUntilIdle()
        assertTrue(completed.isEmpty())
        assertEquals(PaymentProgress.Running("bill", 0, "second"), store.state.value)
    }

    @Test
    fun destroyingAnOldWorkerDoesNotFailTheNewClaim() = runTest {
        val waiting = CompletableDeferred<Unit>()
        val coordinator = PaymentWorkerCoordinator(this, store, { waiting.await() }, { _, _ -> })
        store.tryStart(first)
        coordinator.start(first, 1)
        runCurrent()
        store.cancelIfRunning(first.attemptId)
        store.tryStart(second)
        coordinator.destroy()
        assertEquals(PaymentProgress.Running("bill", 0, "second"), store.state.value)
    }

    @Test
    fun aStaleTimeoutCannotStopTheReplacementAndItsOwnTimeoutIsIdempotent() = runTest {
        val completed = mutableListOf<Int>()
        val waiting = CompletableDeferred<Unit>()
        val coordinator = PaymentWorkerCoordinator(this, store, { waiting.await() }, { id, _ -> completed += id })
        store.tryStart(first)
        coordinator.start(first, 1)
        runCurrent()
        store.cancelIfRunning(first.attemptId)
        store.tryStart(second)
        coordinator.start(second, 2)
        runCurrent()
        coordinator.timeout(1)
        assertTrue(store.state.value is PaymentProgress.Running)
        coordinator.timeout(2)
        coordinator.timeout(2)
        advanceUntilIdle()
        assertEquals(listOf(2), completed)
        assertEquals(PaymentProgress.Failed(PaymentFailureCodes.PROCESSING, "bill", "second"), store.state.value)
    }
}
