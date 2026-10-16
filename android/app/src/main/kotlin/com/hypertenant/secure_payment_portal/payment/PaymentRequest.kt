package com.hypertenant.secure_payment_portal.payment

import com.hypertenant.secure_payment_portal.bridge.ChannelContract
import com.hypertenant.secure_payment_portal.bridge.PaymentChannel

/**
 * What to pay: flat primitives only. No user-facing text and no merchant data crosses the channel,
 * so none can end up in a notification.
 */
data class PaymentRequest(val paymentId: String, val amountMinor: Long, val currency: String, val attemptId: String) {
    companion object {
        /** The values, if they make a payable request; null otherwise. One rule for both entrances. */
        fun of(paymentId: String?, amountMinor: Long, currency: String?, attemptId: String?): PaymentRequest? {
            if (attemptId.isNullOrBlank() || paymentId.isNullOrBlank() || currency.isNullOrBlank() || amountMinor <= 0) return null
            return PaymentRequest(paymentId, amountMinor, currency, attemptId)
        }

        /**
         * The `startPayment` arguments, or null if they are not the documented shape (a map with
         * the schema version, a payment id, a positive integer amount and a currency). Anything
         * else is `INVALID_ARGS`, never an exception.
         */
        fun fromArguments(arguments: Any?): PaymentRequest? {
            val map = arguments as? Map<*, *> ?: return null
            if (integer(map[ChannelContract.KEY_SCHEMA_VERSION]) != ChannelContract.SCHEMA_VERSION.toLong()) {
                return null
            }
            val amount = integer(map[PaymentChannel.KEY_AMOUNT_MINOR]) ?: return null
            return of(
                map[PaymentChannel.KEY_PAYMENT_ID] as? String,
                amount,
                map[PaymentChannel.KEY_CURRENCY] as? String,
                map[PaymentChannel.KEY_ATTEMPT_ID] as? String,
            )
        }

        // A Dart int arrives as an Int or a Long; a fraction is not an amount.
        private fun integer(value: Any?): Long? =
            when (value) {
                is Int -> value.toLong()
                is Long -> value
                else -> null
            }
    }
}
