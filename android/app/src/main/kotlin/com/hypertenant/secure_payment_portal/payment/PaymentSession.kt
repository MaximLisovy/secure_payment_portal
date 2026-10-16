package com.hypertenant.secure_payment_portal.payment

import kotlin.coroutines.cancellation.CancellationException

/**
 * Runs one payment against the [store]: hands it to the [processor], mirrors its progress and
 * publishes how it ended. Pure Kotlin, so the state machine is tested without a service.
 *
 * The caller has already claimed the payment in the store (`tryStart`), which is what makes a
 * second start impossible. A cancel is just the store leaving `Running`: the next progress report
 * returns false, the processor stops, and a late success is refused by the store, so the cancel
 * wins whenever it came first.
 *
 * Cancelling the coroutine itself (the service is going away) is rethrown and publishes nothing:
 * whoever cancelled it decides what the payment's state becomes.
 */
class PaymentSession(
    private val store: PaymentProgressStore,
    private val processor: PaymentProcessor,
    private val now: () -> Long = System::currentTimeMillis,
) {
    suspend fun run(request: PaymentRequest) {
        val outcome =
            try {
                processor.process(request) { percent -> store.reportProgress(request.attemptId, percent) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // Any other failure is the payment failing, never a crash of the service.
                ProcessingOutcome.Failed
            }
        when (outcome) {
            is ProcessingOutcome.Success ->
                store.succeed(
                    request.attemptId,
                    outcome.transactionId,
                    request.amountMinor,
                    request.currency,
                    now(),
                )
            ProcessingOutcome.Declined -> store.fail(request.attemptId, PaymentFailureCodes.DECLINED)
            ProcessingOutcome.Failed -> store.fail(request.attemptId, PaymentFailureCodes.PROCESSING)
            ProcessingOutcome.Stopped -> Unit
        }
    }
}
