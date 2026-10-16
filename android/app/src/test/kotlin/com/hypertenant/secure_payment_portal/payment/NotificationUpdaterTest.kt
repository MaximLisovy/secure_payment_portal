package com.hypertenant.secure_payment_portal.payment

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

private fun running(percent: Int) = PaymentProgress.Running("bill-1", percent, "attempt-1")

class NotificationSpecTest {
    @Test
    fun runningIsAnOngoingNotificationWithProgressAndCancel() {
        val spec = NotificationSpec.forState(running(40))!!

        assertEquals(NotificationKind.PROCESSING, spec.kind)
        assertEquals(40, spec.percent)
        assertTrue(spec.isOngoing && spec.showsProgress && spec.showsCancel)
    }

    @Test
    fun theStartingNotificationIsProcessingAtZero() {
        assertEquals(NotificationSpec(NotificationKind.PROCESSING, 0), NotificationSpec.starting())
    }

    @Test
    fun aSuccessAndAFailureAreLeftOnScreenWithoutProgressOrCancel() {
        val done = NotificationSpec.forState(PaymentProgress.Succeeded("a", "t", 1, "USD", 1, "attempt-1"))!!
        val failed = NotificationSpec.forState(PaymentProgress.Failed("declined", "bill-1", "attempt-1"))!!

        assertEquals(NotificationKind.COMPLETE, done.kind)
        assertEquals(NotificationKind.FAILED, failed.kind)
        for (spec in listOf(done, failed)) {
            assertTrue(!spec.isOngoing && !spec.showsProgress && !spec.showsCancel)
        }
    }

    @Test
    fun aCancelAndAnIdleStoreShowNothing() {
        assertNull(NotificationSpec.forState(PaymentProgress.Cancelled("bill-1", "attempt-1")))
        assertNull(NotificationSpec.forState(PaymentProgress.Idle))
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class NotificationUpdaterTest {
    private val posts = mutableListOf<Pair<Long, Int>>()

    private fun kotlinx.coroutines.test.TestScope.post(spec: NotificationSpec) {
        posts += testScheduler.currentTime to spec.percent
    }

    @Test
    fun theFirstUpdateIsPostedAtOnce() = runTest {
        val states = MutableStateFlow<PaymentProgress>(running(0))
        val job = launch { NotificationUpdater().run(states) { post(it) } }
        runCurrent()

        assertEquals(listOf(0L to 0), posts)
        job.cancel()
    }

    @Test
    fun aBurstOfUpdatesIsPostedAtMostTwiceASecond() = runTest {
        val states = MutableStateFlow<PaymentProgress>(running(0))
        val job = launch { NotificationUpdater().run(states) { post(it) } }
        runCurrent()

        // 100 updates, one every 10 ms: a thousand milliseconds of fast progress.
        for (percent in 1..100) {
            advanceTimeBy(10)
            states.value = running(percent)
            runCurrent()
        }
        advanceUntilIdle()
        job.cancel()

        for (start in 0L..2_000L step 50L) {
            val inWindow = posts.count { it.first > start && it.first <= start + 1_000 }
            assertTrue("$inWindow posts in the second after $start ms: $posts", inWindow <= 2)
        }
        assertTrue("far fewer posts than updates: ${posts.size}", posts.size < 10)
    }

    @Test
    fun theLastValueIsAlwaysPostedEvenIfItArrivesDuringTheWait() = runTest {
        val states = MutableStateFlow<PaymentProgress>(running(0))
        val job = launch { NotificationUpdater().run(states) { post(it) } }
        runCurrent()

        advanceTimeBy(100)
        states.value = running(60)
        advanceTimeBy(100)
        states.value = running(100)
        advanceUntilIdle()
        job.cancel()

        assertEquals("the intermediate 60 was replaced by the latest", listOf(0L to 0, 500L to 100), posts)
    }

    @Test
    fun aQuietPeriodPostsNothing() = runTest {
        val states = MutableStateFlow<PaymentProgress>(running(10))
        val job = launch { NotificationUpdater().run(states) { post(it) } }
        advanceTimeBy(5_000)

        assertEquals(1, posts.size)
        job.cancel()
    }

    @Test
    fun updatesAfterTheWaitAreNotDelayedFurther() = runTest {
        val states = MutableStateFlow<PaymentProgress>(running(0))
        val job = launch { NotificationUpdater().run(states) { post(it) } }
        runCurrent()

        advanceTimeBy(2_000)
        states.value = running(50)
        runCurrent()

        assertEquals(2_000L to 50, posts.last())
        job.cancel()
    }

    @Test
    fun terminalAndOtherStatesAreNotPostedByTheUpdater() = runTest {
        val states = MutableStateFlow<PaymentProgress>(PaymentProgress.Idle)
        val job = launch { NotificationUpdater().run(states) { post(it) } }
        runCurrent()

        states.value = PaymentProgress.Succeeded("a", "t", 1, "USD", 1, "attempt-1")
        advanceTimeBy(1_000)
        states.value = PaymentProgress.Cancelled("bill-1", "attempt-1")
        advanceTimeBy(1_000)

        assertTrue(posts.isEmpty())
        job.cancel()
    }
}
