package com.hypertenant.secure_payment_portal.payment

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** The answer to a request to start a payment. */
sealed interface StartClaim {
    /** The payment is claimed, and [previous] is what to restore if starting the service fails. */
    data class Accepted(val request: PaymentRequest, val previous: PaymentProgress) : StartClaim

    data object AlreadyRunning : StartClaim
}

/**
 * The one place that says where the payment stands, in the process.
 *
 * The plugin claims a payment here before starting the service; the service runs it and publishes
 * progress; cancelling, from the app or from the notification, is the same call. The progress
 * channel collects [state], so a listener that attaches later, even to a new Flutter engine after
 * the app was swiped away, is replayed the current value. That is why it lives in the process and
 * not in the service or the plugin.
 *
 * Every transition is one atomic compare-and-set, and a terminal state can only be reached from
 * `Running` of the same payment. So of a cancel and a finish that race, the first wins and the
 * other is a no-op; and a second start while one runs is refused without disturbing it.
 *
 * It is in memory on purpose: a killed process loses an in-flight payment (see
 * docs/platform_channels.md for what that means and what a real implementation would add).
 */
class PaymentProgressStore(initial: PaymentProgress = PaymentProgress.Idle) {
    private val mutableState = MutableStateFlow(initial)

    val state: StateFlow<PaymentProgress> = mutableState.asStateFlow()

    /** Claims the payment unless one is already running. A terminal state is replaced. */
    fun tryStart(request: PaymentRequest): StartClaim {
        while (true) {
            val current = mutableState.value
            if (current is PaymentProgress.Running) return StartClaim.AlreadyRunning
            val running = PaymentProgress.Running(request.paymentId, percent = 0)
            if (mutableState.compareAndSet(current, running)) {
                return StartClaim.Accepted(request, previous = current)
            }
        }
    }

    /**
     * Gives the claim back because the service could not be started, if nothing has happened
     * since: a cancel or a finish in between wins.
     */
    fun rollback(claim: StartClaim.Accepted) {
        mutableState.compareAndSet(
            PaymentProgress.Running(claim.request.paymentId, percent = 0),
            claim.previous,
        )
    }

    /**
     * Raises the percent of [paymentId]. It never goes down. Returns whether that payment is still
     * running, so the work knows to stop once it is not.
     */
    fun reportProgress(paymentId: String, percent: Int): Boolean {
        val target = percent.coerceIn(0, 100)
        return transition { current ->
            if (current is PaymentProgress.Running && current.paymentId == paymentId) {
                if (target > current.percent) PaymentProgress.Running(paymentId, target) else current
            } else {
                null
            }
        }
    }

    fun succeed(
        paymentId: String,
        transactionId: String,
        amountMinor: Long,
        currency: String,
        completedAtMillis: Long,
    ): Boolean =
        finish(paymentId) {
            PaymentProgress.Succeeded(paymentId, transactionId, amountMinor, currency, completedAtMillis)
        }

    fun fail(paymentId: String, errorCode: String): Boolean =
        finish(paymentId) { PaymentProgress.Failed(errorCode) }

    /** Fails whatever payment is running, for the timeout and for a service that is going away. */
    fun failIfRunning(errorCode: String): Boolean =
        transition { current ->
            if (current is PaymentProgress.Running) PaymentProgress.Failed(errorCode) else null
        }

    /** Cancels the running payment. With nothing running it does nothing. */
    fun cancelIfRunning(): Boolean =
        transition { current ->
            if (current is PaymentProgress.Running) PaymentProgress.Cancelled else null
        }

    private fun finish(paymentId: String, terminal: () -> PaymentProgress): Boolean =
        transition { current ->
            if (current is PaymentProgress.Running && current.paymentId == paymentId) terminal() else null
        }

    /** Applies [next] atomically. Null means "not applicable": nothing changes and it returns false. */
    private inline fun transition(next: (PaymentProgress) -> PaymentProgress?): Boolean {
        while (true) {
            val current = mutableState.value
            val proposed = next(current) ?: return false
            if (proposed == current || mutableState.compareAndSet(current, proposed)) return true
        }
    }

    companion object {
        /** The instance the plugin and the service share. Tests make their own. */
        val shared: PaymentProgressStore by lazy { PaymentProgressStore() }
    }
}
