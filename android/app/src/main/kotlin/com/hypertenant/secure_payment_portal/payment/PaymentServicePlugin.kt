package com.hypertenant.secure_payment_portal.payment

import androidx.core.content.ContextCompat
import com.hypertenant.secure_payment_portal.bridge.PaymentChannel
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
 * The payment channels. Registered in `MainActivity.configureFlutterEngine`. It only wires: calls
 * are handled by [PaymentMethodHandler] and [PaymentStreamHandler], the logic is in plain classes,
 * and the work runs in [PaymentProcessingService], which does not depend on the engine at all.
 *
 * Lifecycle:
 * - engine attach and detach create and release the channels and the coroutine scope; the
 *   service, and the payment it runs, outlive them;
 * - activity attach and detach hand the notification-permission request its Activity and its
 *   result listener, and a detach with a prompt showing counts as a denial. No Activity is kept.
 */
class PaymentServicePlugin : FlutterPlugin, ActivityAware {
    private var scope: CoroutineScope? = null
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    private var permission: ActivityNotificationPermission? = null
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        val store = PaymentProgressStore.shared
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        val permission = ActivityNotificationPermission(context)
        this.scope = scope
        this.permission = permission

        // startForegroundService only in answer to a user action, with the app visible; the
        // system refuses it otherwise, which the starter turns into START_NOT_ALLOWED.
        val starter =
            PaymentStarter(store) { request ->
                ContextCompat.startForegroundService(
                    context,
                    PaymentProcessingService.intentFor(context, request),
                )
            }
        methods =
            MethodChannel(binding.binaryMessenger, PaymentChannel.METHODS).also {
                it.setMethodCallHandler(PaymentMethodHandler(scope, starter, store, permission))
            }
        events =
            EventChannel(binding.binaryMessenger, PaymentChannel.PROGRESS_EVENTS).also {
                it.setStreamHandler(PaymentStreamHandler(scope, store))
            }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        methods = null
        events = null
        scope?.cancel()
        scope = null
        permission = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attach(binding)

    override fun onDetachedFromActivityForConfigChanges() = detach()

    override fun onDetachedFromActivity() = detach()

    private fun attach(binding: ActivityPluginBinding) {
        val permission = permission ?: return
        permission.attach(binding.activity)
        binding.addRequestPermissionsResultListener(permission.resultListener)
        activityBinding = binding
    }

    private fun detach() {
        val permission = permission
        if (permission != null) {
            activityBinding?.removeRequestPermissionsResultListener(permission.resultListener)
            permission.detach()
        }
        activityBinding = null
    }
}
