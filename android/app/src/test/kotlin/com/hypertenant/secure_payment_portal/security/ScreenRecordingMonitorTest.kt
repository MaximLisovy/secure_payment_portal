package com.hypertenant.secure_payment_portal.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

private class FakeSource(var state: Detection = Detection.NOT_DETECTED) : ScreenRecordingSource {
    var starts = 0
    var stops = 0
    private var callback: ((Detection) -> Unit)? = null
    val isRegistered: Boolean
        get() = callback != null

    override fun start(onChange: (Detection) -> Unit): Detection {
        starts++
        callback = onChange
        return state
    }

    override fun stop() {
        stops++
        callback = null
    }

    /** The platform reporting a change. */
    fun fire(next: Detection) {
        state = next
        callback?.invoke(next)
    }

    /** A late delivery of the callback that was registered before the last stop. */
    fun fireStale(old: (Detection) -> Unit, next: Detection) = old(next)

    fun captureCallback(): (Detection) -> Unit = callback!!
}

class ScreenRecordingMonitorTest {
    private val monitor = ScreenRecordingMonitor()
    private val seen = mutableListOf<Detection>()

    private fun listen() = monitor.start { seen += it }

    @Test
    fun withoutAnActivityTheAnswerIsUnknown_neverNotRecording() {
        assertEquals(Detection.UNKNOWN, monitor.snapshot())
    }

    @Test
    fun aSnapshotReadsTheSourceAndLeavesNothingRegistered() {
        val source = FakeSource(Detection.DETECTED)
        monitor.attach(source)

        assertEquals(Detection.DETECTED, monitor.snapshot())

        assertFalse(source.isRegistered)
        assertEquals(1, source.starts)
        assertEquals(1, source.stops)
    }

    @Test
    fun aSnapshotWhileListeningUsesTheTrackedStateWithoutRegisteringAgain() {
        val source = FakeSource(Detection.NOT_DETECTED)
        monitor.attach(source)
        listen()

        source.fire(Detection.DETECTED)

        assertEquals(Detection.DETECTED, monitor.snapshot())
        assertEquals(1, source.starts)
    }

    @Test
    fun startingEmitsTheCurrentStateAtOnceAndRegistersOnce() {
        val source = FakeSource(Detection.DETECTED)
        monitor.attach(source)

        listen()

        assertEquals(listOf(Detection.DETECTED), seen)
        assertEquals(1, source.starts)
    }

    @Test
    fun changesAreEmittedAndRepeatsAreNot() {
        val source = FakeSource(Detection.NOT_DETECTED)
        monitor.attach(source)
        listen()

        source.fire(Detection.DETECTED)
        source.fire(Detection.DETECTED)
        source.fire(Detection.NOT_DETECTED)

        assertEquals(
            listOf(Detection.NOT_DETECTED, Detection.DETECTED, Detection.NOT_DETECTED),
            seen,
        )
    }

    @Test
    fun startingWithNoActivityEmitsUnknown_thenTheRealStateWhenOneAttaches() {
        listen()
        assertEquals(listOf(Detection.UNKNOWN), seen)

        monitor.attach(FakeSource(Detection.DETECTED))

        assertEquals(listOf(Detection.UNKNOWN, Detection.DETECTED), seen)
    }

    @Test
    fun attachingEmitsNothingIfTheStateIsTheSameAsBefore() {
        val first = FakeSource(Detection.NOT_DETECTED)
        monitor.attach(first)
        listen()

        monitor.detach()
        monitor.attach(FakeSource(Detection.NOT_DETECTED))

        assertEquals(listOf(Detection.NOT_DETECTED), seen)
    }

    @Test
    fun aConfigChangeGapEmitsNothing_andAChangeDuringItIsEmittedOnReattach() {
        val first = FakeSource(Detection.NOT_DETECTED)
        monitor.attach(first)
        listen()

        monitor.detach()
        assertFalse("the callback must be released with the Activity", first.isRegistered)
        assertEquals(listOf(Detection.NOT_DETECTED), seen)

        monitor.attach(FakeSource(Detection.DETECTED))
        assertEquals(listOf(Detection.NOT_DETECTED, Detection.DETECTED), seen)
    }

    @Test
    fun stoppingUnregistersAndSilencesLateCallbacks() {
        val source = FakeSource(Detection.NOT_DETECTED)
        monitor.attach(source)
        listen()
        val late = source.captureCallback()

        monitor.stop()
        source.fireStale(late, Detection.DETECTED)

        assertFalse(source.isRegistered)
        assertEquals(listOf(Detection.NOT_DETECTED), seen)
    }

    @Test
    fun aLateCallbackFromADetachedSourceIsIgnored() {
        val old = FakeSource(Detection.NOT_DETECTED)
        monitor.attach(old)
        listen()
        val late = old.captureCallback()

        monitor.detach()
        monitor.attach(FakeSource(Detection.NOT_DETECTED))
        old.fireStale(late, Detection.DETECTED)

        assertEquals(listOf(Detection.NOT_DETECTED), seen)
    }

    @Test
    fun listeningAgainAfterStoppingRegistersAgainAndReplaysTheState() {
        val source = FakeSource(Detection.DETECTED)
        monitor.attach(source)
        listen()
        monitor.stop()

        listen()

        assertEquals(listOf(Detection.DETECTED, Detection.DETECTED), seen)
        assertEquals(2, source.starts)
        assertTrue(source.isRegistered)
    }

    @Test
    fun startingTwiceLeavesOneRegistrationAndTheNewListener() {
        val source = FakeSource(Detection.NOT_DETECTED)
        monitor.attach(source)
        val first = mutableListOf<Detection>()
        monitor.start { first += it }

        listen()
        source.fire(Detection.DETECTED)

        assertEquals(listOf(Detection.NOT_DETECTED), first)
        assertEquals(listOf(Detection.NOT_DETECTED, Detection.DETECTED), seen)
        assertEquals(2, source.starts)
        assertEquals("one live registration", 1, source.starts - source.stops)
    }

    @Test
    fun anApiLevelWithoutTheCallbackReportsUnknownEvenWhileListening() {
        monitor.attach(UnavailableScreenRecordingSource)

        listen()

        assertEquals(listOf(Detection.UNKNOWN), seen)
        assertEquals(Detection.UNKNOWN, monitor.snapshot())
    }

    @Test
    fun theWindowManagerStatesMapToTheWireStates() {
        assertEquals(Detection.DETECTED, RecordingStates.fromWindowManager(1))
        assertEquals(Detection.NOT_DETECTED, RecordingStates.fromWindowManager(0))
        assertEquals(Detection.UNKNOWN, RecordingStates.fromWindowManager(2))
        assertEquals(Detection.UNKNOWN, RecordingStates.fromWindowManager(-1))
    }
}
