package com.hypertenant.secure_payment_portal.security

import android.util.Log
import com.hypertenant.secure_payment_portal.security.checks.CheckOutcome
import com.hypertenant.secure_payment_portal.security.checks.RootCheck
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

/** The verdict of all checks: the state, and the reason codes of the signals that fired. */
data class RootReport(val state: Detection, val signals: List<String>)

/**
 * Runs the checks together, off the main thread, and combines them.
 *
 * - any check fired → `DETECTED`, with the codes of those that did, in the order of [checks];
 * - otherwise, if at least one check ran to a clean result → `NOT_DETECTED`;
 * - otherwise (no check could run, or there are none) → `UNKNOWN`.
 *
 * A check that throws, or does not finish within [perCheckTimeoutMillis], counts as inconclusive and
 * never takes the others down. "Unknown only when every check is inconclusive" keeps one flaky
 * optional check (a process that will not start) from blocking every payment, while a device on
 * which nothing could be checked still reads as unverifiable.
 *
 * The checks run concurrently, so the whole call is bounded by one check's timeout.
 */
class RootDetector(
    private val checks: List<RootCheck>,
    private val dispatcher: CoroutineDispatcher = Dispatchers.IO,
    private val perCheckTimeoutMillis: Long = 2_000,
    private val onCheckFailed: (code: String, error: Throwable) -> Unit = { code, error ->
        // The class name only: a message could carry a path or a package name.
        Log.w(TAG, "root check $code failed: ${error.javaClass.simpleName}")
    },
) {
    suspend fun detect(): RootReport {
        val outcomes =
            withContext(dispatcher) {
                coroutineScope { checks.map { check -> async { runOne(check) } }.awaitAll() }
            }
        val fired = checks.zip(outcomes).filter { (_, outcome) -> outcome == CheckOutcome.Fired }
        val state =
            when {
                fired.isNotEmpty() -> Detection.DETECTED
                outcomes.any { it == CheckOutcome.Clear } -> Detection.NOT_DETECTED
                else -> Detection.UNKNOWN
            }
        return RootReport(state, fired.map { (check, _) -> check.code })
    }

    private suspend fun runOne(check: RootCheck): CheckOutcome =
        try {
            withTimeoutOrNull(perCheckTimeoutMillis) { check.run() } ?: CheckOutcome.Inconclusive
        } catch (e: CancellationException) {
            // Rethrown only if *we* were cancelled. A cancellation raised inside the check itself,
            // such as its own withTimeout running out, is that check failing, nothing more.
            currentCoroutineContext().ensureActive()
            onCheckFailed(check.code, e)
            CheckOutcome.Inconclusive
        } catch (e: Exception) {
            onCheckFailed(check.code, e)
            CheckOutcome.Inconclusive
        }

    private companion object {
        const val TAG = "RootDetector"
    }
}
