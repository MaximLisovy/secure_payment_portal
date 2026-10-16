package com.hypertenant.secure_payment_portal.payment

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PaymentProgressStoreTest {
    private val store = PaymentProgressStore()
    private val request = PaymentRequest("bill-1", 1100, "USD", "attempt-1")

    private fun succeed(id: String = "attempt-1") = store.succeed(id, "TX-1", 1100, "USD", 1_000L)

    @Test
    fun startsIdle() {
        assertEquals(PaymentProgress.Idle, store.state.value)
    }

    @Test
    fun claimingAPaymentReportsItRunningFromZero() {
        val claim = store.tryStart(request)

        assertTrue(claim is StartClaim.Accepted)
        assertEquals(PaymentProgress.Running("bill-1", 0, "attempt-1"), store.state.value)
    }

    @Test
    fun aSecondStartWhileOneRunsIsRefusedAndDisturbsNothing() {
        store.tryStart(request)
        store.reportProgress("attempt-1", 40)

        val second = store.tryStart(PaymentRequest("bill-2", 500, "EUR", "attempt-1"))

        assertEquals(StartClaim.AlreadyRunning, second)
        assertEquals(PaymentProgress.Running("bill-1", 40, "attempt-1"), store.state.value)
    }

    @Test
    fun progressOnlyGoesUp() {
        store.tryStart(request)

        store.reportProgress("attempt-1", 30)
        store.reportProgress("attempt-1", 10)

        assertEquals("a lower percent must not be shown", PaymentProgress.Running("bill-1", 30, "attempt-1"), store.state.value)

        store.reportProgress("attempt-1", 30)
        assertEquals(PaymentProgress.Running("bill-1", 30, "attempt-1"), store.state.value)
    }

    @Test
    fun aPercentOutsideTheRangeIsClamped() {
        store.tryStart(request)

        store.reportProgress("attempt-1", 250)

        assertEquals(PaymentProgress.Running("bill-1", 100, "attempt-1"), store.state.value)
    }

    @Test
    fun progressOfAnotherPaymentIsIgnoredAndTellsTheCallerToStop() {
        store.tryStart(request)

        assertFalse(store.reportProgress("someone-else", 50))
        assertEquals(PaymentProgress.Running("bill-1", 0, "attempt-1"), store.state.value)
    }

    @Test
    fun reportingProgressTellsTheWorkItMayContinue() {
        store.tryStart(request)

        assertTrue(store.reportProgress("attempt-1", 20))
        assertTrue("an unchanged percent is still a running payment", store.reportProgress("attempt-1", 20))
    }

    @Test
    fun aSuccessEndsTheRunWithItsReceipt() {
        store.tryStart(request)

        assertTrue(succeed())

        assertEquals(
            PaymentProgress.Succeeded("bill-1", "TX-1", 1100, "USD", 1_000L, "attempt-1"),
            store.state.value,
        )
    }

    @Test
    fun aFailureEndsTheRunWithItsCode() {
        store.tryStart(request)

        assertTrue(store.fail("attempt-1", PaymentFailureCodes.DECLINED))

        assertEquals(PaymentProgress.Failed("declined", "bill-1", "attempt-1"), store.state.value)
    }

    @Test
    fun cancellingEndsTheRun() {
        store.tryStart(request)

        assertTrue(store.cancelIfRunning("attempt-1"))

        assertEquals(PaymentProgress.Cancelled("bill-1", "attempt-1"), store.state.value)
    }

    @Test
    fun cancellingWithNothingRunningDoesNothing() {
        assertFalse(store.cancelIfRunning("attempt-1"))
        assertEquals(PaymentProgress.Idle, store.state.value)

        store.tryStart(request)
        succeed()
        assertFalse("a finished payment cannot be cancelled", store.cancelIfRunning("attempt-1"))
        assertTrue(store.state.value is PaymentProgress.Succeeded)
    }

    @Test
    fun ofACancelAndAFinishTheFirstWins() {
        store.tryStart(request)
        store.cancelIfRunning("attempt-1")

        assertFalse("too late", succeed())
        assertFalse("too late", store.fail("attempt-1", PaymentFailureCodes.PROCESSING))
        assertEquals(PaymentProgress.Cancelled("bill-1", "attempt-1"), store.state.value)
    }

    @Test
    fun ofAFinishAndACancelTheFirstWinsToo() {
        store.tryStart(request)
        succeed()

        assertFalse("too late", store.cancelIfRunning("attempt-1"))
        assertTrue(store.state.value is PaymentProgress.Succeeded)
    }

    @Test
    fun aTerminalStateCanBeReachedOnlyOnce() {
        store.tryStart(request)

        assertTrue(succeed())
        assertFalse(succeed())
        assertFalse(store.fail("attempt-1", PaymentFailureCodes.PROCESSING))
    }

    @Test
    fun aFinishOfAnotherPaymentIsIgnored() {
        store.tryStart(request)

        assertFalse(succeed("someone-else"))
        assertFalse(store.fail("someone-else", PaymentFailureCodes.PROCESSING))
        assertEquals(PaymentProgress.Running("bill-1", 0, "attempt-1"), store.state.value)
    }

    @Test
    fun terminalStatesStayUntilTheNextStart() {
        store.tryStart(request)
        succeed()

        assertTrue(store.state.value is PaymentProgress.Succeeded)
        assertFalse(store.reportProgress("attempt-1", 50))

        val next = store.tryStart(PaymentRequest("bill-2", 200, "USD", "attempt-1"))
        assertTrue(next is StartClaim.Accepted)
        assertEquals(PaymentProgress.Running("bill-2", 0, "attempt-1"), store.state.value)
    }

    @Test
    fun aNewStartAfterACancelOrAFailureIsAccepted() {
        store.tryStart(request)
        store.cancelIfRunning("attempt-1")
        assertTrue(store.tryStart(request) is StartClaim.Accepted)

        store.fail("attempt-1", PaymentFailureCodes.PROCESSING)
        assertTrue(store.tryStart(request) is StartClaim.Accepted)
    }

    @Test
    fun aClaimThatCouldNotStartTheServiceIsGivenBackToWhatWasThere() {
        store.tryStart(request)
        succeed()
        val before = store.state.value

        val claim = store.tryStart(PaymentRequest("bill-2", 200, "USD", "attempt-1")) as StartClaim.Accepted
        store.rollback(claim)

        assertEquals(before, store.state.value)
        assertTrue("and a retry may start", store.tryStart(request) is StartClaim.Accepted)
    }

    @Test
    fun aRollbackDoesNotUndoAWinningCancelOrProgress() {
        val claim = store.tryStart(request) as StartClaim.Accepted
        store.cancelIfRunning("attempt-1")
        store.rollback(claim)
        assertEquals(PaymentProgress.Cancelled("bill-1", "attempt-1"), store.state.value)

        val second = store.tryStart(request) as StartClaim.Accepted
        store.reportProgress("attempt-1", 10)
        store.rollback(second)
        assertEquals(PaymentProgress.Running("bill-1", 10, "attempt-1"), store.state.value)
    }

    @Test
    fun ofManyConcurrentStartsExactlyOneIsAccepted() {
        val pool = Executors.newFixedThreadPool(8)
        val start = CountDownLatch(1)
        val done = CountDownLatch(16)
        val accepted = AtomicInteger()
        repeat(16) { index ->
            pool.execute {
                start.await()
                if (store.tryStart(PaymentRequest("bill-$index", 100, "USD", "attempt-1")) is StartClaim.Accepted) {
                    accepted.incrementAndGet()
                }
                done.countDown()
            }
        }

        start.countDown()
        assertTrue(done.await(5, TimeUnit.SECONDS))
        pool.shutdown()

        assertEquals(1, accepted.get())
    }

    @Test
    fun ofAConcurrentCancelAndFinishExactlyOneWins() {
        repeat(200) {
            val raced = PaymentProgressStore()
            raced.tryStart(request)
            val pool = Executors.newFixedThreadPool(2)
            val go = CountDownLatch(1)
            val wins = AtomicInteger()
            val done = CountDownLatch(2)
            pool.execute {
                go.await()
                if (raced.cancelIfRunning("attempt-1")) wins.incrementAndGet()
                done.countDown()
            }
            pool.execute {
                go.await()
                if (raced.succeed("attempt-1", "TX", 1, "USD", 1L)) wins.incrementAndGet()
                done.countDown()
            }
            go.countDown()
            assertTrue(done.await(5, TimeUnit.SECONDS))
            pool.shutdown()

            assertEquals(1, wins.get())
            assertTrue(raced.state.value.isTerminal)
        }
    }
}
