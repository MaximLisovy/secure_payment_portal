package com.hypertenant.secure_payment_portal.security

import io.flutter.plugin.common.EventChannel

/**
 * The `…/security/screen_recording` event channel.
 *
 * `onListen` registers with the monitor, which emits the current state at once (the contract:
 * replay on listen) and then each change, all on the main thread. `onCancel` unregisters and drops
 * the sink. The engine may call `onListen` again after `onCancel`, or even without it (it calls
 * `onCancel(null)` itself first): either way there is one registration and one sink.
 */
class RecordingStreamHandler(private val monitor: ScreenRecordingMonitor) :
    EventChannel.StreamHandler {
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        monitor.start { state -> sink?.success(SecurityStatusPayload.recording(state)) }
    }

    override fun onCancel(arguments: Any?) {
        monitor.stop()
        sink = null
    }
}
