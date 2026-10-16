package com.hypertenant.secure_payment_portal.payment

import com.hypertenant.secure_payment_portal.bridge.AndroidMainThread
import com.hypertenant.secure_payment_portal.bridge.ChannelContract
import com.hypertenant.secure_payment_portal.bridge.ChannelErrorCodes
import com.hypertenant.secure_payment_portal.bridge.MainThread
import com.hypertenant.secure_payment_portal.bridge.PaymentChannel
import com.hypertenant.secure_payment_portal.bridge.SafeResult
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * The `…/payment` method channel, on the main thread where Flutter delivers calls. Nothing here
 * blocks: starting a payment claims it and asks the system to start the service, and the work
 * runs there; a cancel is one store call; the permission prompt is awaited in the plugin scope.
 *
 * Every reply goes through [SafeResult]: once, on main. An unexpected exception is `INTERNAL`
 * with a fixed message, never its text.
 */
class PaymentMethodHandler(
    private val scope: CoroutineScope,
    private val starter: PaymentStarter,
    private val store: PaymentProgressStore,
    private val permission: NotificationPermission,
    private val mainThread: MainThread = AndroidMainThread,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, rawResult: MethodChannel.Result) {
        val result = SafeResult(rawResult, mainThread)
        try {
            when (call.method) {
                PaymentChannel.START_PAYMENT -> startPayment(call, result)
                PaymentChannel.CANCEL_PAYMENT, PaymentChannel.GET_PAYMENT_SNAPSHOT -> {
                    val arguments = call.arguments as? Map<*, *>
                    val attemptId = arguments?.get(PaymentChannel.KEY_ATTEMPT_ID) as? String
                    if (attemptId.isNullOrBlank() || arguments[ChannelContract.KEY_SCHEMA_VERSION] != ChannelContract.SCHEMA_VERSION) {
                        result.error(ChannelErrorCodes.INVALID_ARGS, "The call needs an attempt identity.", null)
                        return
                    }
                    if (call.method == PaymentChannel.GET_PAYMENT_SNAPSHOT) {
                        result.success(PaymentProgressPayload.of(store.snapshot(attemptId)))
                    } else {
                        store.cancelIfRunning(attemptId)
                        result.success(null)
                    }
                }
                PaymentChannel.REQUEST_NOTIFICATION_PERMISSION -> requestPermission(result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error(ChannelErrorCodes.INTERNAL, INTERNAL_MESSAGE, null)
        }
    }

    private fun startPayment(call: MethodCall, result: SafeResult) {
        val request = PaymentRequest.fromArguments(call.arguments)
        if (request == null) {
            result.error(ChannelErrorCodes.INVALID_ARGS, "The payment request is not valid.", null)
            return
        }
        when (starter.start(request)) {
            StartResult.Accepted -> result.success(null)
            StartResult.AlreadyRunning ->
                result.error(ChannelErrorCodes.ALREADY_RUNNING, "A payment is already running.", null)
            StartResult.NotAllowed ->
                result.error(
                    ChannelErrorCodes.START_NOT_ALLOWED,
                    "The system did not allow the payment to start.",
                    null,
                )
            StartResult.Failed -> result.error(ChannelErrorCodes.INTERNAL, INTERNAL_MESSAGE, null)
        }
    }

    private fun requestPermission(result: SafeResult) {
        scope.launch {
            try {
                permission.request()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // An optional prompt failure also counts as interaction complete.
                result.success(null)
                return@launch
            }
            // Permission affects Android notifications only; Dart awaits completion.
            result.success(null)
        }
    }

    private companion object {
        const val INTERNAL_MESSAGE = "The payment call failed."
    }
}
