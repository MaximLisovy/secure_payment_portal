package com.hypertenant.secure_payment_portal.security.checks

import com.hypertenant.secure_payment_portal.security.probes.FileProbe

/**
 * Looks at every path, so a denied one cannot hide a later path that exists.
 *
 * - a path that exists → [CheckOutcome.Fired], whatever else was denied;
 * - none exists and none was denied → [CheckOutcome.Clear];
 * - none exists but a probe was denied (`SecurityException`) → that exception is rethrown, so
 *   `RootDetector` records the check as inconclusive: the path was not seen, which is not the same
 *   as absent.
 */
internal fun FileProbe.outcomeFor(paths: List<String>): CheckOutcome {
    var denied: SecurityException? = null
    for (path in paths) {
        try {
            if (exists(path)) return CheckOutcome.Fired
        } catch (e: SecurityException) {
            denied = denied ?: e
        }
    }
    denied?.let { throw it }
    return CheckOutcome.Clear
}
