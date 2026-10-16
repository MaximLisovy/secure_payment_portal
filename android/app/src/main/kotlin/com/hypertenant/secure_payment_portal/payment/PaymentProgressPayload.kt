package com.hypertenant.secure_payment_portal.payment

import com.hypertenant.secure_payment_portal.bridge.ChannelContract
import com.hypertenant.secure_payment_portal.bridge.PaymentChannel

/**
 * The wire maps of the progress channel, as documented in docs/platform_channels.md: flat maps of
 * primitives with explicit keys and a `schemaVersion`. Each state carries only its own fields.
 */
object PaymentProgressPayload {
    fun of(progress: PaymentProgress): Map<String, Any> {
        val base = mapOf(ChannelContract.KEY_SCHEMA_VERSION to ChannelContract.SCHEMA_VERSION)
        return when (progress) {
            PaymentProgress.Idle -> base + (PaymentChannel.KEY_STATE to PaymentChannel.STATE_IDLE)
            is PaymentProgress.Running ->
                base +
                    mapOf(
                        PaymentChannel.KEY_STATE to PaymentChannel.STATE_RUNNING,
                        PaymentChannel.KEY_PAYMENT_ID to progress.paymentId,
                        PaymentChannel.KEY_ATTEMPT_ID to progress.attemptId,
                        PaymentChannel.KEY_PERCENT to progress.percent,
                    )
            is PaymentProgress.Succeeded ->
                base +
                    mapOf(
                        PaymentChannel.KEY_STATE to PaymentChannel.STATE_SUCCEEDED,
                        PaymentChannel.KEY_PAYMENT_ID to progress.paymentId,
                        PaymentChannel.KEY_ATTEMPT_ID to progress.attemptId,
                        PaymentChannel.KEY_TRANSACTION_ID to progress.transactionId,
                        PaymentChannel.KEY_AMOUNT_MINOR to progress.amountMinor,
                        PaymentChannel.KEY_CURRENCY to progress.currency,
                        PaymentChannel.KEY_COMPLETED_AT_MILLIS to progress.completedAtMillis,
                    )
            is PaymentProgress.Failed ->
                base +
                    mapOf(
                        PaymentChannel.KEY_STATE to PaymentChannel.STATE_FAILED,
                        PaymentChannel.KEY_ERROR_CODE to progress.errorCode,
                        PaymentChannel.KEY_PAYMENT_ID to progress.paymentId,
                        PaymentChannel.KEY_ATTEMPT_ID to progress.attemptId,
                    )
            is PaymentProgress.Cancelled -> base + mapOf(
                PaymentChannel.KEY_STATE to PaymentChannel.STATE_CANCELLED,
                PaymentChannel.KEY_PAYMENT_ID to progress.paymentId,
                PaymentChannel.KEY_ATTEMPT_ID to progress.attemptId,
            )
        }
    }
}
