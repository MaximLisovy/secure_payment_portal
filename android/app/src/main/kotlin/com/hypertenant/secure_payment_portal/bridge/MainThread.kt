package com.hypertenant.secure_payment_portal.bridge

import android.os.Handler
import android.os.Looper

/**
 * The platform main thread, as a port. Channel replies and event emissions must happen on it, and
 * putting it behind an interface lets the code that depends on it run in plain JVM tests.
 */
interface MainThread {
    fun isCurrent(): Boolean

    fun post(block: () -> Unit)
}

object AndroidMainThread : MainThread {
    private val handler by lazy { Handler(Looper.getMainLooper()) }

    // Looper.isCurrentThread: API 23, minSdk is 24.
    override fun isCurrent(): Boolean = Looper.getMainLooper().isCurrentThread

    override fun post(block: () -> Unit) {
        handler.post(block)
    }
}
