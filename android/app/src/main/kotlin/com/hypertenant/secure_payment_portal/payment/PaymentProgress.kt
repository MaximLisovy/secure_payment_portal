package com.hypertenant.secure_payment_portal.payment

import com.hypertenant.secure_payment_portal.bridge.PaymentChannel

/**
 * Where the payment stands, as the progress channel reports it. One state at a time; the terminal
 * states ([Succeeded], [Failed], [Cancelled]) stay current until the next payment starts.
 */
sealed interface PaymentProgress {
    /** Nothing running and nothing finished. */
    data object Idle : PaymentProgress

    data class Running(val paymentId: String, val percent: Int) : PaymentProgress

    data class Succeeded(
        val paymentId: String,
        val transactionId: String,
        val amountMinor: Long,
        val currency: String,
        val completedAtMillis: Long,
    ) : PaymentProgress

    /** [errorCode] is a `PaymentChannel.FAILURE_*` value. */
    data class Failed(val errorCode: String) : PaymentProgress

    data object Cancelled : PaymentProgress
}

val PaymentProgress.isTerminal: Boolean
    get() =
        this is PaymentProgress.Succeeded ||
            this is PaymentProgress.Failed ||
            this is PaymentProgress.Cancelled

/** The failure codes a payment can end with. */
object PaymentFailureCodes {
    const val DECLINED = PaymentChannel.FAILURE_DECLINED
    const val PROCESSING = PaymentChannel.FAILURE_PROCESSING
}
