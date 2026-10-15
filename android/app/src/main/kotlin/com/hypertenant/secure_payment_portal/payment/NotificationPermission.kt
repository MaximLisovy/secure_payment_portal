package com.hypertenant.secure_payment_portal.payment

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.hypertenant.secure_payment_portal.bridge.NotificationPermissionWire
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CompletableDeferred

/** The answer to a request for the notification permission. */
enum class PermissionResult(val wire: String) {
    GRANTED(NotificationPermissionWire.GRANTED),
    DENIED(NotificationPermissionWire.DENIED),

    /** Below API 33 there is no permission to ask for. */
    NOT_REQUIRED(NotificationPermissionWire.NOT_REQUIRED),
}

interface NotificationPermission {
    /** Asks, if it must, and reports. Never throws: no way to ask is a denial. */
    suspend fun request(): PermissionResult
}

/**
 * Joins the system prompt to a coroutine: [await] shows it through [ask] unless one is already
 * showing, and every caller waits for the same answer. Main thread only.
 */
class PermissionRequestTracker {
    private var pending: CompletableDeferred<Boolean>? = null

    suspend fun await(ask: () -> Unit): Boolean {
        val waiting = pending
        if (waiting != null) return waiting.await()
        val deferred = CompletableDeferred<Boolean>()
        pending = deferred
        try {
            ask()
        } catch (e: Exception) {
            pending = null
            return false
        }
        return deferred.await()
    }

    /** The system answered. */
    fun onResult(granted: Boolean) {
        val deferred = pending ?: return
        pending = null
        deferred.complete(granted)
    }

    /** The prompt can no longer be answered (the Activity went away): that is a denial. */
    fun abort() = onResult(false)
}

/**
 * Asks for `POST_NOTIFICATIONS` (API 33+) through the current Activity. The answer arrives in
 * [resultListener], which the plugin registers while an Activity is attached. Denial is a normal
 * answer: the payment runs without its notification being shown.
 */
class ActivityNotificationPermission(private val context: Context) : NotificationPermission {
    private val tracker = PermissionRequestTracker()
    private var activity: Activity? = null

    val resultListener = PluginRegistry.RequestPermissionsResultListener { code, _, results ->
        if (code != REQUEST_CODE) {
            false
        } else {
            tracker.onResult(results.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            true
        }
    }

    fun attach(activity: Activity) {
        this.activity = activity
    }

    fun detach() {
        activity = null
        tracker.abort()
    }

    override suspend fun request(): PermissionResult {
        // POST_NOTIFICATIONS exists from API 33.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return PermissionResult.NOT_REQUIRED
        val granted =
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        if (granted) return PermissionResult.GRANTED
        val current = activity ?: return PermissionResult.DENIED
        val answered =
            tracker.await {
                ActivityCompat.requestPermissions(
                    current,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_CODE,
                )
            }
        return if (answered) PermissionResult.GRANTED else PermissionResult.DENIED
    }

    private companion object {
        const val REQUEST_CODE = 7_301
    }
}
