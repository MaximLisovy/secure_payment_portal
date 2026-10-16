package com.hypertenant.secure_payment_portal.security.checks

/** What one heuristic found. */
sealed interface CheckOutcome {
    /** The heuristic ran and the signal is absent. */
    data object Clear : CheckOutcome

    /** The signal is present. */
    data object Fired : CheckOutcome

    /** The heuristic could not run or could not be trusted. */
    data object Inconclusive : CheckOutcome
}

/**
 * One independent root heuristic, reporting under a stable wire reason [code].
 *
 * Client-side root checks are heuristics: tools such as Magisk DenyList and Zygisk can hide a rooted
 * device from them, so a clean result means "not detected", never "proven safe". A production app
 * would add the server-verified Play Integrity API. Domain decides what a signal is worth; a check
 * only reports it.
 */
interface RootCheck {
    val code: String

    /** Whether a conclusive clean result contributes to a not-detected verdict. */
    val isStrong: Boolean

    suspend fun run(): CheckOutcome
}
