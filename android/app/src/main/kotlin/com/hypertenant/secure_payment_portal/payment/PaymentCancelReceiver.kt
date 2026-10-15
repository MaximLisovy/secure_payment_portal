package com.hypertenant.secure_payment_portal.payment

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** What a cancel request does, without Android: it asks the store to cancel, nothing more. */
class PaymentCancelAction(private val store: PaymentProgressStore) {
    /** Returns whether a running payment was cancelled. Anything else is ignored. */
    fun handle(action: String?): Boolean = action == ACTION_CANCEL && store.cancelIfRunning()

    companion object {
        const val ACTION_CANCEL = "com.hypertenant.secure_payment_portal.payment.CANCEL"
    }
}

/**
 * The notification's Cancel action. A **non-exported** receiver, reached through an immutable
 * `PendingIntent.getBroadcast`, so only this app's own notification can send it.
 *
 * It does not depend on the service being alive and is not a service start, so no background
 * start restriction can get in the way of a cancel: it writes the process-wide store, and the
 * service, if it is running, sees the payment leave `Running` and winds down.
 */
class PaymentCancelReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        PaymentCancelAction(PaymentProgressStore.shared).handle(intent.action)
    }
}
