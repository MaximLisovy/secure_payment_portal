package com.hypertenant.secure_payment_portal.security

import com.hypertenant.secure_payment_portal.testing.FakeEventSink
import com.hypertenant.secure_payment_portal.testing.FakeRecordingSource
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingStreamHandlerTest {
    private val monitor = ScreenRecordingMonitor()
    private val handler = RecordingStreamHandler(monitor)
    private val source = FakeRecordingSource(Detection.NOT_DETECTED)

    private fun event(state: String) = mapOf("schemaVersion" to 1, "screenRecording" to state)

    @Test
    fun listeningReplaysTheCurrentStateAtOnce() {
        monitor.attach(source)
        val sink = FakeEventSink()

        handler.onListen(null, sink)

        assertEquals(listOf<Any?>(event("notDetected")), sink.events)
    }

    @Test
    fun withNoActivityTheReplayIsUnknownNeverNotDetected() {
        val sink = FakeEventSink()

        handler.onListen(null, sink)

        assertEquals(listOf<Any?>(event("unknown")), sink.events)
    }

    @Test
    fun eachChangeIsSentOnceAfterTheReplay() {
        monitor.attach(source)
        val sink = FakeEventSink()
        handler.onListen(null, sink)

        source.fire(Detection.DETECTED)
        source.fire(Detection.DETECTED)
        source.fire(Detection.NOT_DETECTED)

        assertEquals(
            listOf<Any?>(event("notDetected"), event("detected"), event("notDetected")),
            sink.events,
        )
    }

    @Test
    fun cancellingReleasesTheCallbackAndSilencesTheSink() {
        monitor.attach(source)
        val sink = FakeEventSink()
        handler.onListen(null, sink)

        handler.onCancel(null)
        source.fire(Detection.DETECTED)

        assertFalse("the platform callback must be removed", source.isRegistered)
        assertEquals(1, sink.events.size)
    }

    @Test
    fun listeningAgainAfterCancellingWorksAndReplaysTheCurrentState() {
        monitor.attach(source)
        handler.onListen(null, FakeEventSink())
        handler.onCancel(null)
        source.state = Detection.DETECTED
        val second = FakeEventSink()

        handler.onListen(null, second)

        assertEquals(listOf<Any?>(event("detected")), second.events)
        assertTrue(source.isRegistered)
    }

    // The engine itself calls onCancel before a second onListen, but the handler must also survive
    // a second onListen that arrives without one.
    @Test
    fun aSecondListenWithoutACancelLeavesOneRegistrationAndTheNewSink() {
        monitor.attach(source)
        val first = FakeEventSink()
        val second = FakeEventSink()
        handler.onListen(null, first)

        handler.onListen(null, second)
        source.fire(Detection.DETECTED)

        assertEquals(1, first.events.size)
        assertEquals(listOf<Any?>(event("notDetected"), event("detected")), second.events)
        assertEquals(1, source.starts - source.stops)
    }

    @Test
    fun theActivityComingBackAfterAConfigChangeDoesNotRepeatAnUnchangedState() {
        monitor.attach(source)
        val sink = FakeEventSink()
        handler.onListen(null, sink)

        monitor.detach()
        monitor.attach(FakeRecordingSource(Detection.NOT_DETECTED))

        assertEquals(1, sink.events.size)
    }
}
