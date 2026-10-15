package com.hypertenant.secure_payment_portal.payment

import java.util.UUID
import kotlinx.coroutines.delay

/** How the work of one payment ended. */
sealed interface ProcessingOutcome {
    data class Success(val transactionId: String) : ProcessingOutcome

    data object Declined : ProcessingOutcome

    data object Failed : ProcessingOutcome

    /** The payment was stopped from outside (a cancel). There is nothing left to publish. */
    data object Stopped : ProcessingOutcome
}

/**
 * The work behind a payment. A port: today a simulation, tomorrow a call to a payment backend,
 * which would run on `Dispatchers.IO` inside [process] and need nothing else to change.
 */
interface PaymentProcessor {
    /**
     * Processes [request]. [report] publishes a percent and returns whether the payment is still
     * running; once it returns false the processor must stop and return [ProcessingOutcome.Stopped].
     */
    suspend fun process(request: PaymentRequest, report: (percent: Int) -> Boolean): ProcessingOutcome
}

/**
 * A payment that takes [steps] steps of [stepDelayMillis], reports each one, waits one more step
 * and succeeds. It mirrors the Dart fake's script, with more and shorter steps, so there is time
 * to put the app in the background and to see the notification throttle.
 *
 * It **always succeeds**. A declined or failed payment is played by the simulated source in Dart
 * (the demo panel), where the outcome is a scenario; a real backend would decide it here.
 */
class SimulatedPaymentProcessor(
    private val steps: Int = DEFAULT_STEPS,
    private val stepDelayMillis: Long = DEFAULT_STEP_DELAY_MILLIS,
    private val newTransactionId: () -> String = { "TX-" + UUID.randomUUID().toString().take(8).uppercase() },
) : PaymentProcessor {
    init {
        require(steps > 0) { "at least one step" }
        require(stepDelayMillis >= 0) { "a delay cannot be negative" }
    }

    override suspend fun process(
        request: PaymentRequest,
        report: (percent: Int) -> Boolean,
    ): ProcessingOutcome {
        for (step in 1..steps) {
            delay(stepDelayMillis)
            if (!report(step * 100 / steps)) return ProcessingOutcome.Stopped
        }
        delay(stepDelayMillis)
        return ProcessingOutcome.Success(newTransactionId())
    }

    companion object {
        const val DEFAULT_STEPS = 20
        const val DEFAULT_STEP_DELAY_MILLIS = 400L
    }
}
