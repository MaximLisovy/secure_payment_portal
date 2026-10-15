package com.hypertenant.secure_payment_portal.security

import android.app.Activity
import android.content.pm.ApplicationInfo
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import com.hypertenant.secure_payment_portal.bridge.SecurityChannel
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

/**
 * Root detection, screen recording detection and `FLAG_SECURE`, exposed to Dart. Registered in
 * `MainActivity.configureFlutterEngine`. It only wires: the channels are handled by
 * [SecurityMethodHandler] and [RecordingStreamHandler], the logic lives in plain classes.
 *
 * Lifecycle:
 * - engine attach/detach creates and releases the channels and the coroutine scope;
 * - activity attach and re-attach (after a config change) hand the new `Window` to the controller,
 *   which re-applies `FLAG_SECURE`, and the new `WindowManager` to the recording monitor;
 * - activity detach, for a config change or for good, drops both. No `Activity` is kept here.
 */
class SecurityPlugin : FlutterPlugin, ActivityAware {
    private val windowController = SecureWindowController()
    private val recordingMonitor = ScreenRecordingMonitor()
    private var scope: CoroutineScope? = null
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        this.scope = scope
        val debuggable = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

        methods =
            MethodChannel(binding.binaryMessenger, SecurityChannel.METHODS).also {
                it.setMethodCallHandler(
                    SecurityMethodHandler(
                        scope = scope,
                        rootDetector = RootDetector(defaultRootChecks(context)),
                        windowController = windowController,
                        recordingMonitor = recordingMonitor,
                        // Debug builds only; the line holds states and reason codes, no user data.
                        log = if (debuggable) ({ message -> Log.d(TAG, message) }) else null,
                    )
                )
            }
        events =
            EventChannel(binding.binaryMessenger, SecurityChannel.RECORDING_EVENTS).also {
                it.setStreamHandler(RecordingStreamHandler(recordingMonitor))
            }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        methods = null
        events = null
        recordingMonitor.stop()
        recordingMonitor.detach()
        windowController.detach()
        scope?.cancel()
        scope = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding.activity)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        attach(binding.activity)

    override fun onDetachedFromActivityForConfigChanges() = detach()

    override fun onDetachedFromActivity() = detach()

    private fun attach(activity: Activity) {
        windowController.attach(ActivityWindowTarget(activity.window))
        recordingMonitor.attach(recordingSourceFor(activity))
    }

    private fun detach() {
        windowController.detach()
        recordingMonitor.detach()
    }

    private fun recordingSourceFor(activity: Activity): ScreenRecordingSource =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            // addScreenRecordingCallback: API 35. The main executor puts every callback on main.
            WindowManagerRecordingSource(activity.windowManager, ContextCompat.getMainExecutor(activity))
        } else {
            UnavailableScreenRecordingSource
        }

    private companion object {
        const val TAG = "SecurityPlugin"
    }
}
