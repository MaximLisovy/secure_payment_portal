package com.hypertenant.secure_payment_portal.security

import android.view.WindowManager
import androidx.annotation.RequiresApi
import java.util.concurrent.Executor
import java.util.function.Consumer

/** One way to learn whether the screen is being recorded. A port, so the monitor runs in JVM tests. */
interface ScreenRecordingSource {
    /**
     * Starts reporting. Returns the state right now and calls [onChange] for each later change,
     * on the main thread.
     */
    fun start(onChange: (Detection) -> Unit): Detection

    /** Stops reporting. Safe to call when not started. */
    fun stop()
}

/**
 * Below API 35 there is no official way to ask whether the screen is being recorded, so the answer
 * is `UNKNOWN`: never `NOT_DETECTED`, which would claim knowledge nobody has. (The API 34
 * `Activity.registerScreenCaptureCallback` reports *screenshots*, not recordings, and a
 * `DisplayManager` heuristic would also flag casting and mirroring, so neither is used.)
 */
object UnavailableScreenRecordingSource : ScreenRecordingSource {
    override fun start(onChange: (Detection) -> Unit): Detection = Detection.UNKNOWN

    override fun stop() = Unit
}

/** The `WindowManager` screen recording states as a [Detection]. */
object RecordingStates {
    fun fromWindowManager(state: Int): Detection =
        when (state) {
            WindowManager.SCREEN_RECORDING_STATE_VISIBLE -> Detection.DETECTED
            WindowManager.SCREEN_RECORDING_STATE_NOT_VISIBLE -> Detection.NOT_DETECTED
            else -> Detection.UNKNOWN
        }
}

/**
 * `WindowManager.addScreenRecordingCallback`: API 35, needs `DETECT_SCREEN_RECORDING`. It reports
 * whether this app's windows are visible in a screen recording, and it is registered on the
 * Activity's own `WindowManager`, so it exists only while an Activity does.
 *
 * [executor] should be the main executor, so the callback (and everything it triggers) runs on the
 * main thread.
 */
@RequiresApi(35)
class WindowManagerRecordingSource(
    private val windowManager: WindowManager,
    private val executor: Executor,
) : ScreenRecordingSource {
    private var callback: Consumer<Int>? = null

    override fun start(onChange: (Detection) -> Unit): Detection {
        stop()
        val consumer = Consumer<Int> { state -> onChange(RecordingStates.fromWindowManager(state)) }
        callback = consumer
        // Registering returns the current state.
        return RecordingStates.fromWindowManager(
            windowManager.addScreenRecordingCallback(executor, consumer)
        )
    }

    override fun stop() {
        callback?.let(windowManager::removeScreenRecordingCallback)
        callback = null
    }
}
