package com.hypertenant.secure_payment_portal.bridge

import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Wraps a [MethodChannel.Result] so it is answered **exactly once**, and **on the main thread**.
 *
 * Flutter throws "Reply already submitted" on a second reply, and replies must not come from a
 * background thread. A coroutine that finishes after its caller gave up, or a handler with two exit
 * paths, can break either rule; this wrapper makes both impossible instead of relying on every call
 * site getting it right. A second reply is ignored and logged, never thrown.
 */
class SafeResult(
    private val delegate: MethodChannel.Result,
    private val mainThread: MainThread = AndroidMainThread,
    private val onDuplicate: (String) -> Unit = { Log.w(TAG, it) },
) : MethodChannel.Result {
    private val replied = AtomicBoolean(false)

    override fun success(result: Any?) = reply("success") { delegate.success(result) }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) =
        reply("error($errorCode)") { delegate.error(errorCode, errorMessage, errorDetails) }

    override fun notImplemented() = reply("notImplemented") { delegate.notImplemented() }

    private fun reply(what: String, send: () -> Unit) {
        if (!replied.compareAndSet(false, true)) {
            onDuplicate("Ignored a second reply: $what")
            return
        }
        if (mainThread.isCurrent()) send() else mainThread.post(send)
    }

    private companion object {
        const val TAG = "SafeResult"
    }
}
