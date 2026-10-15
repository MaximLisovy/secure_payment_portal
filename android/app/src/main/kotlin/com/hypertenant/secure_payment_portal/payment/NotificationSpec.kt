package com.hypertenant.secure_payment_portal.payment

enum class NotificationKind { PROCESSING, COMPLETE, FAILED }

/**
 * What the payment notification shows, decided without Android so it can be tested. The factory
 * turns it into a real notification.
 *
 * Processing is ongoing, with a progress bar and a Cancel action. Complete and failed are left on
 * screen when the service stops ("remove only on cancel"): dismissible, no progress, no action.
 * A cancel shows nothing, and neither does an idle store.
 */
data class NotificationSpec(val kind: NotificationKind, val percent: Int = 0) {
    val isOngoing: Boolean get() = kind == NotificationKind.PROCESSING
    val showsProgress: Boolean get() = kind == NotificationKind.PROCESSING
    val showsCancel: Boolean get() = kind == NotificationKind.PROCESSING

    companion object {
        /** The notification the service goes foreground with, before the first progress arrives. */
        fun starting() = NotificationSpec(NotificationKind.PROCESSING, percent = 0)

        fun forState(state: PaymentProgress): NotificationSpec? =
            when (state) {
                is PaymentProgress.Running -> NotificationSpec(NotificationKind.PROCESSING, state.percent)
                is PaymentProgress.Succeeded -> NotificationSpec(NotificationKind.COMPLETE)
                is PaymentProgress.Failed -> NotificationSpec(NotificationKind.FAILED)
                PaymentProgress.Cancelled,
                PaymentProgress.Idle -> null
            }
    }
}
