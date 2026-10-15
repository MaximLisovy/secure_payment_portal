package com.hypertenant.secure_payment_portal.security

import androidx.annotation.MainThread

/**
 * `FLAG_SECURE` with a **reference count**: the flag goes on when the first screen asks and comes off
 * when every ask has been balanced, so one screen leaving never unprotects another.
 *
 * - **No window, no protection.** [enable] with no window attached fails and changes nothing. The
 *   count is not a promise made to a window that is not there.
 * - **Config changes.** The count outlives the window: [detach] keeps it, and [attach] puts the flag
 *   on the new window at once if anyone still holds protection.
 * - **The truth.** [protection] reads the flag from the window itself, not from what was asked for,
 *   so the app's security policy sees what a screenshot would see.
 *
 * Main thread only: window flags must be changed on the UI thread, and every caller is already there.
 */
@MainThread
class SecureWindowController {
    private var holders = 0
    private var target: SecureWindowTarget? = null

    /** How many [enable] calls are still unbalanced. */
    val holderCount: Int
        get() = holders

    /** Begins using [window], applying the flag to it if someone holds protection. */
    fun attach(window: SecureWindowTarget) {
        target = window
        if (holders > 0) window.setSecure(true)
    }

    /**
     * Stops using the window; the count is kept. The window is not touched: it is going away, and
     * the next one is protected by [attach].
     */
    fun detach() {
        target = null
    }

    /** Returns true if the window is now protected, false if there is no window to protect. */
    fun enable(): Boolean {
        val window = target ?: return false
        holders++
        // Also re-asserts a flag something else cleared.
        if (!window.isSecure) window.setSecure(true)
        return true
    }

    /** Balances one [enable]. With nothing to balance it does nothing. */
    fun disable() {
        if (holders == 0) return
        holders--
        if (holders == 0) target?.setSecure(false)
    }

    /** Whether the window is hidden from capture right now. */
    fun protection(): WindowProtection =
        if (target?.isSecure == true) WindowProtection.ACTIVE else WindowProtection.INACTIVE
}
