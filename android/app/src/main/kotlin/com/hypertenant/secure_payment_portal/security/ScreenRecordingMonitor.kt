package com.hypertenant.secure_payment_portal.security

import androidx.annotation.MainThread

/**
 * Tracks whether the screen is being recorded, across the Activity's lifecycle.
 *
 * The platform callback lives on an Activity's window, but the Dart side listens for as long as the
 * engine runs. This class joins the two:
 *
 * - [start] and [stop] follow the Dart listener (EventChannel `onListen` / `onCancel`);
 * - [attach] and [detach] follow the Activity (`ActivityAware`).
 *
 * The callback is registered only while both are true. A config change detaches and re-attaches in
 * a moment; nothing is emitted for the gap, and after re-attaching a change is emitted only if the
 * state really is different. Equal consecutive states are never emitted twice. Without a source
 * (no Activity, or an API level without the callback) the state is `UNKNOWN`, never "not recording".
 *
 * Main thread only.
 */
@MainThread
class ScreenRecordingMonitor {
    private var source: ScreenRecordingSource? = null
    private var listener: ((Detection) -> Unit)? = null
    private var registered: ScreenRecordingSource? = null

    /** Told apart from older registrations, so a late callback of a stopped one is ignored. */
    private var generation = 0

    private var current = Detection.UNKNOWN

    /**
     * The state right now. While listening it is the tracked state; otherwise it asks the source
     * and unregisters at once, which is what a one-shot status query needs.
     */
    fun snapshot(): Detection {
        val source = source ?: return Detection.UNKNOWN
        if (registered != null) return current
        val state = source.start {}
        source.stop()
        return state
    }

    /** Begins reporting to [onChange], starting with the current state. */
    fun start(onChange: (Detection) -> Unit) {
        stop()
        listener = onChange
        register()
        onChange(current)
    }

    fun stop() {
        unregister()
        listener = null
    }

    /** The Activity is there (or back after a config change): use its window. */
    fun attach(newSource: ScreenRecordingSource) {
        unregister()
        source = newSource
        if (listener != null) {
            val before = current
            register()
            if (current != before) listener?.invoke(current)
        }
    }

    /** The Activity is going away. The last known state is kept and nothing is emitted. */
    fun detach() {
        unregister()
        source = null
    }

    private fun register() {
        val source = source
        if (source == null) {
            current = Detection.UNKNOWN
            return
        }
        val mine = ++generation
        registered = source
        current = source.start { state -> onSourceChange(mine, state) }
    }

    private fun unregister() {
        generation++
        registered?.stop()
        registered = null
    }

    private fun onSourceChange(owner: Int, state: Detection) {
        if (owner != generation || state == current) return
        current = state
        listener?.invoke(state)
    }
}
