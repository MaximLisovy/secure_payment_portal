package com.hypertenant.secure_payment_portal.security

import android.util.Log
import com.hypertenant.secure_payment_portal.security.checks.CheckOutcome
import com.hypertenant.secure_payment_portal.security.checks.RootCheck
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withTimeoutOrNull

/**
 * The verdict of all checks: the state, and the reason codes of the signals that fired.
 * [inconclusive] names the checks that could not run; it is for diagnosis (the debug log) and is
 * not sent over the channel.
 */
data class RootReport(
    val state: Detection,
    val signals: List<String>,
    val inconclusive: List<String> = emptyList(),
) {
    init {
        // The wire contract: signals are present exactly when root is detected.
        require((state == Detection.DETECTED) == signals.isNotEmpty()) {
            "signals must be non-empty exactly when root is detected"
        }
    }
}

/**
 * Runs the checks together, off the main thread, and combines them.
 *
 * - any check fired → `DETECTED`, with the codes of those that did, in the order of [checks];
 * - otherwise, if at least one strong check ran to a clean result → `NOT_DETECTED`;
 * - otherwise (no check could run, or there are none) → `UNKNOWN`.
 *
 * A check that throws, or does not finish within [perCheckTimeoutMillis], counts as inconclusive and
 * never takes the others down. A clean weak check (build tags/type) is insufficient:
 * when no strong check completes conclusively, an otherwise clean result is UNKNOWN.
 * This may block a legitimate device whose strong probes are all unavailable.
 *
 * Probes run concurrently in a detector-owned IO scope, outside the awaiting scope.
 * Each await is bounded by [perCheckTimeoutMillis], subject to caller scheduling.
 * A blocking system call may keep its IO thread after timeout; its late result is
 * abandoned, never joined into the reply. [close] cancels the probe scope on engine detach.
 * This bounds waiting, not the lifetime of an uninterruptible operating-system call.
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
    private val probes = CoroutineScope(SupervisorJob() + dispatcher)

    fun close() = probes.cancel()

    suspend fun detect(): RootReport {
        val outcomes =
            coroutineScope { checks.map { check -> async { runOne(check) } }.awaitAll() }
        val fired = checks.zip(outcomes).filter { (_, outcome) -> outcome == CheckOutcome.Fired }
        val state =
            when {
                fired.isNotEmpty() -> Detection.DETECTED
                checks.zip(outcomes).any { (check, outcome) -> check.isStrong && outcome == CheckOutcome.Clear } -> Detection.NOT_DETECTED
                else -> Detection.UNKNOWN
            }
        val inconclusive =
            checks.zip(outcomes).filter { (_, outcome) -> outcome == CheckOutcome.Inconclusive }
        return RootReport(
            state,
            fired.map { (check, _) -> check.code },
            inconclusive.map { (check, _) -> check.code },
        )
    }

    private suspend fun runOne(check: RootCheck): CheckOutcome {
        // This worker is not a child of the caller: structured cancellation must
        // not wait for a blocking File/PackageManager/process call to return.
        val probe = probes.async { check.run() }
        return try {
            withTimeoutOrNull(perCheckTimeoutMillis) { probe.await() } ?: CheckOutcome.Inconclusive
        } catch (e: CancellationException) {
            // Caller cancellation propagates; a cancellation inside the probe
            // (including its own timeout) is only an inconclusive check.
            currentCoroutineContext().ensureActive()
            onCheckFailed(check.code, e)
            CheckOutcome.Inconclusive
        } catch (e: Exception) {
            onCheckFailed(check.code, e)
            CheckOutcome.Inconclusive
        } finally {
            // cancel() does not join; a late blocking probe cannot extend waiting.
            probe.cancel()
        }
    }

    private companion object {
        const val TAG = "RootDetector"
    }
}
