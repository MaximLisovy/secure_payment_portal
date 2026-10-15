package com.hypertenant.secure_payment_portal.payment

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

private val request = PaymentRequest("bill-1", 1100, "USD")

private class ScriptedProcessor(private val script: suspend (report: (Int) -> Boolean) -> ProcessingOutcome) :
    PaymentProcessor {
    override suspend fun process(request: PaymentRequest, report: (Int) -> Boolean) = script(report)
}

@OptIn(ExperimentalCoroutinesApi::class)
class SimulatedPaymentProcessorTest {
    @Test
    fun reportsEachStepAndSucceedsOneStepAfterTheLast() = runTest {
        val percents = mutableListOf<Int>()
        val processor = SimulatedPaymentProcessor(steps = 4, stepDelayMillis = 100) { "TX-1" }

        val outcome = processor.process(request) { percents += it; true }

        assertEquals(listOf(25, 50, 75, 100), percents)
        assertEquals(ProcessingOutcome.Success("TX-1"), outcome)
        assertEquals("four steps and the last wait", 500L, testScheduler.currentTime)
    }

    @Test
    fun theDefaultScriptIsTwentyStepsOfFourHundredMilliseconds() = runTest {
        val percents = mutableListOf<Int>()

        SimulatedPaymentProcessor().process(request) { percents += it; true }

        assertEquals((1..20).map { it * 5 }, percents)
        assertEquals(21 * 400L, testScheduler.currentTime)
    }

    @Test
    fun stopsAsSoonAsTheReportSaysThePaymentIsNoLongerRunning() = runTest {
        val processor = SimulatedPaymentProcessor(steps = 10, stepDelayMillis = 100)
        var reports = 0

        val outcome = processor.process(request) { reports++; reports < 3 }

        assertEquals(ProcessingOutcome.Stopped, outcome)
        assertEquals(3, reports)
        assertEquals("no further waiting", 300L, testScheduler.currentTime)
    }

    @Test
    fun alwaysSucceeds() = runTest {
        repeat(5) {
            val outcome = SimulatedPaymentProcessor(steps = 2, stepDelayMillis = 1).process(request) { true }
            assertTrue(outcome is ProcessingOutcome.Success)
        }
    }

    @Test
    fun eachPaymentGetsItsOwnTransactionId() = runTest {
        val processor = SimulatedPaymentProcessor(steps = 1, stepDelayMillis = 1)

        val a = processor.process(request) { true } as ProcessingOutcome.Success
        val b = processor.process(request) { true } as ProcessingOutcome.Success

        assertTrue(a.transactionId != b.transactionId)
        assertTrue(a.transactionId.startsWith("TX-"))
    }

    @Test(expected = IllegalArgumentException::class)
    fun needsAtLeastOneStep() {
        SimulatedPaymentProcessor(steps = 0)
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class PaymentSessionTest {
    private val store = PaymentProgressStore()

    private fun claim() = store.tryStart(request)

    private fun session(processor: PaymentProcessor) = PaymentSession(store, processor) { 1_700_000_000_000L }

    @Test
    fun aSuccessPublishesTheReceipt() = runTest {
        claim()

        session(SimulatedPaymentProcessor(steps = 2, stepDelayMillis = 10) { "TX-7" }).run(request)

        assertEquals(
            PaymentProgress.Succeeded("bill-1", "TX-7", 1100, "USD", 1_700_000_000_000L),
            store.state.value,
        )
    }

    @Test
    fun progressReachesTheStoreInOrderAndEndsInOneTerminalState() = runTest {
        claim()
        val seen = mutableListOf<PaymentProgress>()
        val collector = launch { store.state.collect { seen += it } }
        runCurrent()

        val run = launch {
            session(SimulatedPaymentProcessor(steps = 4, stepDelayMillis = 100) { "TX" }).run(request)
        }
        advanceUntilIdle()
        collector.cancel()
        run.cancel()

        val running = seen.filterIsInstance<PaymentProgress.Running>().map { it.percent }
        assertEquals(listOf(0, 25, 50, 75, 100), running)
        assertEquals(1, seen.count { it.isTerminal })
        assertTrue(seen.last() is PaymentProgress.Succeeded)
    }

    @Test
    fun aDeclineAndAFailureArePublishedWithTheirCodes() = runTest {
        claim()
        session(ScriptedProcessor { ProcessingOutcome.Declined }).run(request)
        assertEquals(PaymentProgress.Failed("declined"), store.state.value)

        claim()
        session(ScriptedProcessor { ProcessingOutcome.Failed }).run(request)
        assertEquals(PaymentProgress.Failed("processing_failed"), store.state.value)
    }

    @Test
    fun aProcessorThatThrowsIsAFailedPaymentNotACrash() = runTest {
        claim()

        session(ScriptedProcessor { throw IllegalStateException("backend down") }).run(request)

        assertEquals(PaymentProgress.Failed("processing_failed"), store.state.value)
    }

    @Test
    fun aCancelMidRunStopsTheWorkAndTheCancelStands() = runTest {
        claim()
        val processor = SimulatedPaymentProcessor(steps = 10, stepDelayMillis = 100) { "TX" }
        val run = launch { session(processor).run(request) }
        advanceTimeBy(350)
        runCurrent()
        assertTrue(store.state.value is PaymentProgress.Running)

        store.cancelIfRunning()
        advanceUntilIdle()

        assertEquals(PaymentProgress.Cancelled, store.state.value)
        assertTrue(run.isCompleted)
        assertEquals("it stopped at the next step, not at the end", 400L, testScheduler.currentTime)
    }

    @Test
    fun aCancelDuringTheLastWaitBeatsTheSuccess() = runTest {
        claim()
        val processor = SimulatedPaymentProcessor(steps = 2, stepDelayMillis = 100) { "TX" }
        val run = launch { session(processor).run(request) }
        advanceTimeBy(250)
        runCurrent()
        assertEquals(PaymentProgress.Running("bill-1", 100), store.state.value)

        store.cancelIfRunning()
        advanceUntilIdle()

        assertEquals(PaymentProgress.Cancelled, store.state.value)
        assertTrue(run.isCompleted)
    }

    @Test
    fun aStoppedOutcomePublishesNothing() = runTest {
        claim()
        store.cancelIfRunning()

        session(ScriptedProcessor { ProcessingOutcome.Stopped }).run(request)

        assertEquals(PaymentProgress.Cancelled, store.state.value)
    }

    @Test
    fun cancellingTheCoroutineIsRethrownAndPublishesNothing() = runTest {
        claim()
        var cancelled: Throwable? = null
        val run = launch {
            try {
                session(ScriptedProcessor { delay(10_000); ProcessingOutcome.Failed }).run(request)
            } catch (e: CancellationException) {
                cancelled = e
                throw e
            }
        }
        runCurrent()

        run.cancel()
        advanceUntilIdle()

        assertTrue(cancelled is CancellationException)
        assertFalse("the caller decides what a cancelled coroutine means", store.state.value.isTerminal)
    }
}
