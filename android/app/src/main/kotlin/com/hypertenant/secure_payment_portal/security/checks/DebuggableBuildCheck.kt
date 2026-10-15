package com.hypertenant.secure_payment_portal.security.checks

import com.hypertenant.secure_payment_portal.bridge.RootReasonCodes
import com.hypertenant.secure_payment_portal.security.probes.SystemProperties

/**
 * The system itself is a debuggable build: `ro.debuggable=1` or `ro.secure=0`. **Weak** signal: it
 * is normal on developer builds and many emulator images. If neither property can be read the
 * result is inconclusive; one readable benign property is enough for a clean result.
 */
class DebuggableBuildCheck(private val properties: SystemProperties) : RootCheck {
    override val code = RootReasonCodes.DEBUGGABLE_BUILD

    override suspend fun run(): CheckOutcome {
        val debuggable = properties.get("ro.debuggable")
        val secure = properties.get("ro.secure")
        return when {
            debuggable == "1" || secure == "0" -> CheckOutcome.Fired
            debuggable == null && secure == null -> CheckOutcome.Inconclusive
            else -> CheckOutcome.Clear
        }
    }
}
