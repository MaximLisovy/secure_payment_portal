package com.hypertenant.secure_payment_portal.payment

import com.hypertenant.secure_payment_portal.bridge.AndroidMainThread
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
                PaymentChannel.CANCEL_PAYMENT -> {
                    store.cancelIfRunning()
                    result.success(null)
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
            val answer =
                try {
                    permission.request()
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    PermissionResult.DENIED
                }
            result.success(answer.wire)
        }
    }

    private companion object {
        const val INTERNAL_MESSAGE = "The payment call failed."
    }
}
