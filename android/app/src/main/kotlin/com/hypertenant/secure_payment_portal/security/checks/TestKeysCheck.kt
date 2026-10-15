package com.hypertenant.secure_payment_portal.security.checks

import com.hypertenant.secure_payment_portal.bridge.RootReasonCodes
import com.hypertenant.secure_payment_portal.security.probes.BuildInfo

/**
 * The build is signed with the public AOSP test keys. **Weak** signal: it is normal on emulator
 * images and developer builds, so it is not proof of root on its own.
 */
class TestKeysCheck(private val build: BuildInfo) : RootCheck {
    override val code = RootReasonCodes.TEST_KEYS

    override suspend fun run(): CheckOutcome {
        val tags = build.tags ?: return CheckOutcome.Inconclusive
        return if (tags.contains("test-keys")) CheckOutcome.Fired else CheckOutcome.Clear
    }
}
