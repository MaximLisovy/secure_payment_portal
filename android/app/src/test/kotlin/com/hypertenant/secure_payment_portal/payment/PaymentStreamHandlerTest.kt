package com.hypertenant.secure_payment_portal.payment

import com.hypertenant.secure_payment_portal.testing.FakeEventSink
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PaymentStreamHandlerTest {
    private val store = PaymentProgressStore()
    private val request = PaymentRequest("bill-1", 1100, "USD")

    private fun state(name: String, vararg extra: Pair<String, Any>) =
        mapOf<String, Any>("schemaVersion" to 1, "state" to name) + extra

    @Test
    fun listeningReplaysIdleBeforeAnyPayment() = runTest {
        val handler = PaymentStreamHandler(this, store)
        val sink = FakeEventSink()

        handler.onListen(null, sink)
        runCurrent()

        assertEquals(listOf<Any?>(state("idle")), sink.events)
        handler.onCancel(null)
    }

    @Test
    fun followsTheRunFromTheClaimToTheReceipt() = runTest {
        val handler = PaymentStreamHandler(this, store)
        val sink = FakeEventSink()
        handler.onListen(null, sink)
        runCurrent()

        store.tryStart(request)
        runCurrent()
        store.reportProgress("bill-1", 50)
        runCurrent()
        store.succeed("bill-1", "TX-1", 1100, "USD", 99L)
        runCurrent()

        assertEquals(
            listOf<Any?>(
                state("idle"),
                state("running", "paymentId" to "bill-1", "percent" to 0),
                state("running", "paymentId" to "bill-1", "percent" to 50),
                state(
                    "succeeded",
                    "paymentId" to "bill-1",
                    "transactionId" to "TX-1",
                    "amountMinor" to 1100L,
                    "currency" to "USD",
                    "completedAtMillis" to 99L,
                ),
            ),
            sink.events,
        )
        handler.onCancel(null)
    }

    @Test
    fun aListenerThatArrivesLaterIsReplayedTheCurrentStateWithItsProgress() = runTest {
        store.tryStart(request)
        store.reportProgress("bill-1", 70)
        val handler = PaymentStreamHandler(this, store)
        val sink = FakeEventSink()

        handler.onListen(null, sink)
        runCurrent()

        assertEquals(
            listOf<Any?>(state("running", "paymentId" to "bill-1", "percent" to 70)),
            sink.events,
        )
        handler.onCancel(null)
    }

    @Test
    fun aTerminalStateIsReplayedUntilTheNextPayment() = runTest {
        store.tryStart(request)
        store.cancelIfRunning()
        val handler = PaymentStreamHandler(this, store)

        val first = FakeEventSink()
        handler.onListen(null, first)
        runCurrent()
        handler.onCancel(null)
        val second = FakeEventSink()
        handler.onListen(null, second)
        runCurrent()

        assertEquals(listOf<Any?>(state("cancelled")), first.events)
        assertEquals(listOf<Any?>(state("cancelled")), second.events)
        handler.onCancel(null)
    }

    @Test
    fun cancellingStopsTheCollectorAndSilencesTheSink() = runTest {
        val handler = PaymentStreamHandler(this, store)
        val sink = FakeEventSink()
        handler.onListen(null, sink)
        runCurrent()

        handler.onCancel(null)
        store.tryStart(request)
        advanceUntilIdle()

        assertEquals(1, sink.events.size)
    }

    @Test
    fun aSecondListenWithoutACancelLeavesOneCollectorAndTheNewSink() = runTest {
        val handler = PaymentStreamHandler(this, store)
        val first = FakeEventSink()
        val second = FakeEventSink()
        handler.onListen(null, first)
        runCurrent()

        handler.onListen(null, second)
        runCurrent()
        store.tryStart(request)
        runCurrent()

        assertEquals("the old sink hears nothing more", 1, first.events.size)
        assertEquals(2, second.events.size)
        assertTrue(second.events.last() == state("running", "paymentId" to "bill-1", "percent" to 0))
        handler.onCancel(null)
    }
}
