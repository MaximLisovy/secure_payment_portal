package com.hypertenant.secure_payment_portal.security.checks

import com.hypertenant.secure_payment_portal.bridge.RootReasonCodes
import com.hypertenant.secure_payment_portal.security.probes.BuildInfo

/**
 * The system image is a debuggable build (`Build.TYPE` is `userdebug` or `eng`). **Weak** signal:
 * it is normal on developer builds and on many emulator images, so it is not proof of root.
 *
 * It reads the public `Build.TYPE`. The obvious source, `ro.debuggable` / `ro.secure` through
 * `getprop`, is not readable by an app: SELinux hides those properties, and the command prints
 * nothing (checked on an API 36 device), which would make this check always inconclusive.
 */
class DebuggableBuildCheck(private val build: BuildInfo) : RootCheck {
    override val code = RootReasonCodes.DEBUGGABLE_BUILD

    override suspend fun run(): CheckOutcome {
        val type = build.type ?: return CheckOutcome.Inconclusive
        return if (type in DEBUGGABLE_TYPES) CheckOutcome.Fired else CheckOutcome.Clear
    }

    private companion object {
        val DEBUGGABLE_TYPES = setOf("userdebug", "eng")
    }
}
