package com.hypertenant.secure_payment_portal.payment

import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * Owns the service worker, independently of Android. Main thread only.
 * A replacement cancels and joins the old worker before running; only the current
 * generation may finish the service. Duplicate delivery advances the stop startId.
 */
class PaymentWorkerCoordinator(
    private val scope: CoroutineScope,
    private val store: PaymentProgressStore,
    private val process: suspend (PaymentRequest) -> Unit,
    private val finished: (Int, PaymentProgress) -> Unit,
) {
    private var work: Job? = null
    private var current: PaymentRequest? = null
    private var generation = 0
    private var latestStartId = 0

    val hasWork: Boolean get() = work?.isActive == true

    /** Even an obsolete Intent advances Android's startId used by stopSelf. */
    fun observeDelivery(startId: Int) {
        latestStartId = startId
    }

    fun start(request: PaymentRequest, startId: Int): Boolean {
        val state = store.state.value
        if (state !is PaymentProgress.Running || state.attemptId != request.attemptId) return false
        latestStartId = startId
        if (current?.attemptId == request.attemptId && hasWork) return true
        val previous = work
        previous?.cancel()
        val owner = ++generation
        current = request
        work = scope.launch(start = CoroutineStart.LAZY) {
            previous?.join()
            try {
                process(request)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                store.fail(request.attemptId, PaymentFailureCodes.PROCESSING)
            }
            if (owner != generation) return@launch
            current = null
            work = null
            val outcome = store.state.value
            // A replacement may be claimed before its start Intent is delivered.
            // Its forthcoming worker owns the foreground notification now.
            if (outcome !is PaymentProgress.Running || outcome.attemptId == request.attemptId) {
                finished(latestStartId, outcome)
            }
        }
        work?.start()
        return true
    }

    fun timeout(startId: Int) {
        if (startId != latestStartId) return
        val request = current ?: return
        store.fail(request.attemptId, PaymentFailureCodes.PROCESSING)
        generation++
        work?.cancel()
        work = null
        current = null
        val outcome = store.state.value
        if (outcome !is PaymentProgress.Running || outcome.attemptId == request.attemptId) {
            finished(startId, outcome)
        }
    }

    fun destroy() {
        generation++
        current?.let { store.fail(it.attemptId, PaymentFailureCodes.PROCESSING) }
        current = null
        work?.cancel()
        work = null
    }
}
