package com.hypertenant.secure_payment_portal.payment

import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.conflate

/**
 * Turns progress into notification updates, at most one per [minIntervalMillis] (two per second by
 * default; the system rate-limits notifications anyway and a fast stream would only be dropped).
 *
 * The first update is posted at once. While waiting, newer values replace older ones, so what is
 * posted next is always the latest and the last value is never lost. It posts only `Running`
 * states and runs until cancelled: the service posts the final notification itself, at once, so a
 * terminal state is never held back by the throttle.
 */
class NotificationUpdater(private val minIntervalMillis: Long = DEFAULT_INTERVAL_MILLIS) {
    suspend fun run(states: Flow<PaymentProgress>, post: (NotificationSpec) -> Unit) {
        states.conflate().collect { state ->
            val spec = NotificationSpec.forState(state)
            if (spec?.kind == NotificationKind.PROCESSING) {
                post(spec)
                delay(minIntervalMillis)
            }
        }
    }

    companion object {
        const val DEFAULT_INTERVAL_MILLIS = 500L
    }
}
