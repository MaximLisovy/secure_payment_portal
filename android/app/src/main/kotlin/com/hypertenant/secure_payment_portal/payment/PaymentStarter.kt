package com.hypertenant.secure_payment_portal.payment

/** How a request to start a payment ended. */
sealed interface StartResult {
    data object Accepted : StartResult

    data object AlreadyRunning : StartResult

    /** The system refused to start the foreground service, typically because the app is in the background. */
    data object NotAllowed : StartResult

    data object Failed : StartResult
}

/** Starts the foreground service for [PaymentRequest]. Throws if the system refuses. */
fun interface ServiceLauncher {
    fun launch(request: PaymentRequest)
}

/**
 * Starts a payment: claims it in the store, then starts the service, and gives the claim back if
 * the service cannot be started.
 *
 * The claim comes first, and is one atomic step, so two starts that race cannot both get through
 * and the second is refused without touching the first. The service is started only for a payment
 * that was claimed; one that was claimed but could not be started is rolled back, so the next
 * attempt is not refused as "already running" for a payment that never ran.
 */
class PaymentStarter(private val store: PaymentProgressStore, private val launcher: ServiceLauncher) {
    fun start(request: PaymentRequest): StartResult {
        val claim = store.tryStart(request)
        if (claim !is StartClaim.Accepted) return StartResult.AlreadyRunning
        return try {
            launcher.launch(request)
            StartResult.Accepted
        } catch (e: Exception) {
            store.rollback(claim)
            ServiceStartErrors.resultFor(e)
        }
    }
}

object ServiceStartErrors {
    /**
     * `ForegroundServiceStartNotAllowedException` (API 31) is an `IllegalStateException`, and so is
     * the "app is in the background" error that API 26 to 30 throw. Matching the superclass covers
     * both without naming an API 31 class, which would not load on older devices. Anything else
     * (a missing permission, say) is a failure of the start, not a refusal.
     */
    fun resultFor(error: Throwable): StartResult =
        if (error is IllegalStateException) StartResult.NotAllowed else StartResult.Failed
}
