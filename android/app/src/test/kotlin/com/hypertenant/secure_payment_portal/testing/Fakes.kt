package com.hypertenant.secure_payment_portal.testing

import com.hypertenant.secure_payment_portal.bridge.MainThread
import com.hypertenant.secure_payment_portal.security.Detection
import com.hypertenant.secure_payment_portal.security.ScreenRecordingSource
import com.hypertenant.secure_payment_portal.security.SecureWindowTarget
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// Test doubles shared by the JVM tests. Each stands for one port of the production code.

/** A [MethodChannel.Result] that records what it was answered with. */
class RecordingResult : MethodChannel.Result {
    val replies = mutableListOf<String>()

    @Synchronized
    override fun success(result: Any?) {
        replies += "success($result)"
    }

    @Synchronized
    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        replies += "error($errorCode,$errorMessage,$errorDetails)"
    }

    @Synchronized
    override fun notImplemented() {
        replies += "notImplemented"
    }
}

/** The main thread as a test controls it: either already on it, or queueing work to run later. */
class FakeMainThread(var onMain: Boolean) : MainThread {
    val posted = mutableListOf<() -> Unit>()

    override fun isCurrent() = onMain

    override fun post(block: () -> Unit) {
        posted += block
    }

    fun runPosted() {
        val pending = posted.toList()
        posted.clear()
        pending.forEach { it() }
    }
}

/** A window that records every flag change it is asked to make. */
class FakeWindow : SecureWindowTarget {
    var flag = false
    val calls = mutableListOf<Boolean>()

    override val isSecure: Boolean
        get() = flag

    override fun setSecure(secure: Boolean) {
        calls += secure
        flag = secure
    }
}

/** A screen recording source the test drives by hand. */
class FakeRecordingSource(var state: Detection = Detection.NOT_DETECTED) : ScreenRecordingSource {
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

/** An [EventChannel.EventSink] that records what was sent. */
class FakeEventSink : EventChannel.EventSink {
    val events = mutableListOf<Any?>()
    var ended = false

    override fun success(event: Any?) {
        events += event
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        events += "error($errorCode)"
    }

    override fun endOfStream() {
        ended = true
    }
}
