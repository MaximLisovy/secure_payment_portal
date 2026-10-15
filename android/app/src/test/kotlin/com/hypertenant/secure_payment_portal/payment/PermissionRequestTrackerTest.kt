package com.hypertenant.secure_payment_portal.payment

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PermissionRequestTrackerTest {
    private val tracker = PermissionRequestTracker()
    private var asked = 0

    @Test
    fun waitsForTheSystemsAnswer() = runTest {
        var answer: Boolean? = null
        val waiting = launch { answer = tracker.await { asked++ } }
        runCurrent()
        assertEquals(1, asked)
        assertEquals("still waiting for the user", null, answer)

        tracker.onResult(true)
        advanceUntilIdle()

        assertEquals(true, answer)
        assertTrue(waiting.isCompleted)
    }

    @Test
    fun aDenialIsAnAnswer() = runTest {
        var answer: Boolean? = null
        launch { answer = tracker.await { asked++ } }
        runCurrent()

        tracker.onResult(false)
        advanceUntilIdle()

        assertEquals(false, answer)
    }

    @Test
    fun twoRequestsWhileOneIsShowingShareOnePromptAndOneAnswer() = runTest {
        val answers = mutableListOf<Boolean>()
        launch { answers += tracker.await { asked++ } }
        launch { answers += tracker.await { asked++ } }
        runCurrent()

        tracker.onResult(true)
        advanceUntilIdle()

        assertEquals(1, asked)
        assertEquals(listOf(true, true), answers)
    }

    @Test
    fun aLaterRequestAsksAgain() = runTest {
        launch { tracker.await { asked++ } }
        runCurrent()
        tracker.onResult(false)
        advanceUntilIdle()

        launch { tracker.await { asked++ } }
        runCurrent()

        assertEquals(2, asked)
        tracker.onResult(true)
    }

    @Test
    fun anAnswerWithNothingWaitingIsIgnored() {
        tracker.onResult(true)
        tracker.abort()
    }

    @Test
    fun aPromptThatCannotBeShownIsADenialNotACrash() = runTest {
        val answer = tracker.await { throw IllegalStateException("no window") }

        assertFalse(answer)
    }

    @Test
    fun anActivityThatGoesAwayDeniesAPendingRequest() = runTest {
        var answer: Boolean? = null
        launch { answer = tracker.await { asked++ } }
        runCurrent()

        tracker.abort()
        advanceUntilIdle()

        assertEquals(false, answer)
    }
}
