package com.hypertenant.secure_payment_portal.security

import com.hypertenant.secure_payment_portal.bridge.AndroidMainThread
import com.hypertenant.secure_payment_portal.bridge.ChannelErrorCodes
import com.hypertenant.secure_payment_portal.bridge.MainThread
import com.hypertenant.secure_payment_portal.bridge.SafeResult
import com.hypertenant.secure_payment_portal.bridge.SecurityChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * The `…/security` method channel. Runs on the main thread, where Flutter delivers the calls:
 *
 * - `getSecurityStatus` waits for the root checks, which run on `Dispatchers.IO` inside
 *   [RootDetector], then reads the recording state and the window flag back on the main thread;
 * - `enableSecureWindow` and `disableSecureWindow` touch the `Window`, so they stay on main and
 *   answer at once.
 *
 * Every reply goes through [SafeResult]: once, on main. An unexpected exception becomes
 * `INTERNAL` without its message, because a message could carry a path. [scope] belongs to the
 * plugin and is cancelled with the engine, which silences any call still waiting.
 */
class SecurityMethodHandler(
    private val scope: CoroutineScope,
    private val rootDetector: RootDetector,
    private val windowController: SecureWindowController,
    private val recordingMonitor: ScreenRecordingMonitor,
    private val mainThread: MainThread = AndroidMainThread,
    private val log: ((String) -> Unit)? = null,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, rawResult: MethodChannel.Result) {
        val result = SafeResult(rawResult, mainThread)
        try {
            when (call.method) {
                SecurityChannel.GET_SECURITY_STATUS -> getSecurityStatus(result)
                SecurityChannel.ENABLE_SECURE_WINDOW -> enableSecureWindow(result)
                SecurityChannel.DISABLE_SECURE_WINDOW -> disableSecureWindow(result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error(ChannelErrorCodes.INTERNAL, INTERNAL_MESSAGE, null)
        }
    }

    private fun getSecurityStatus(result: SafeResult) {
        scope.launch {
            try {
                val root = rootDetector.detect()
                // Back on the main thread: the monitor and the window are main-thread objects.
                val recording = recordingMonitor.snapshot()
                val window = windowController.protection()
                log?.invoke(
                    "status root=${root.state.wire} signals=${root.signals} " +
                        "recording=${recording.wire} window=${window.wire}"
                )
                result.success(SecurityStatusPayload.status(root, recording, window))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                result.error(ChannelErrorCodes.INTERNAL, INTERNAL_MESSAGE, null)
            }
        }
    }

    private fun enableSecureWindow(result: SafeResult) {
        if (windowController.enable()) {
            result.success(null)
        } else {
            result.error(ChannelErrorCodes.UNAVAILABLE, "There is no window to protect.", null)
        }
    }

    private fun disableSecureWindow(result: SafeResult) {
        windowController.disable()
        result.success(null)
    }

    private companion object {
        const val INTERNAL_MESSAGE = "The security call failed."
    }
}
