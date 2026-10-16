package com.hypertenant.secure_payment_portal.security.checks

import com.hypertenant.secure_payment_portal.bridge.RootReasonCodes
import com.hypertenant.secure_payment_portal.security.probes.FileProbe

/** A `su` binary in one of the places root tools put it. Strong signal. */
class SuBinaryCheck(
    private val files: FileProbe,
    private val paths: List<String> = SU_PATHS,
) : RootCheck {
    override val code = RootReasonCodes.SU_BINARY
    override val isStrong = true

    override suspend fun run(): CheckOutcome =
        if (paths.any(files::exists)) CheckOutcome.Fired else CheckOutcome.Clear

    companion object {
        val SU_PATHS =
            listOf(
                "/system/bin/su",
                "/system/xbin/su",
                "/sbin/su",
                "/system/sbin/su",
                "/vendor/bin/su",
                "/su/bin/su",
                "/system/su",
                "/system/bin/.ext/.su",
                "/data/local/su",
                "/data/local/bin/su",
                "/data/local/xbin/su",
            )
    }
}
