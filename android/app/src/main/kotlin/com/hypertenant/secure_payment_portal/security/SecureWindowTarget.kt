package com.hypertenant.secure_payment_portal.security

import android.view.Window
import android.view.WindowManager

/**
 * The window that gets `FLAG_SECURE`. A port, so [SecureWindowController] runs in plain JVM tests.
 * All calls are on the main thread.
 */
interface SecureWindowTarget {
    /** Whether the window carries the secure flag right now, read from the window itself. */
    val isSecure: Boolean

    fun setSecure(secure: Boolean)
}

/**
 * An Activity's [Window]. `FLAG_SECURE` hides the window from screenshots, screen recording and the
 * recents thumbnail on every API level, so there is nothing to guard here.
 *
 * Do not keep it past `onDetachedFromActivity`: it holds the window, and through it the Activity.
 */
class ActivityWindowTarget(private val window: Window) : SecureWindowTarget {
    override val isSecure: Boolean
        get() = window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0

    override fun setSecure(secure: Boolean) {
        if (secure) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
