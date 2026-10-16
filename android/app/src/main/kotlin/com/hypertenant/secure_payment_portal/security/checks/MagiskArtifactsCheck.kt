package com.hypertenant.secure_payment_portal.security.checks

import com.hypertenant.secure_payment_portal.bridge.RootReasonCodes
import com.hypertenant.secure_payment_portal.security.probes.FileProbe

/**
 * Files and directories Magisk leaves behind. Strong signal when found.
 *
 * Most of these paths are not readable by an unprivileged app on a modern Android (SELinux, the
 * app sandbox), so a clean result here says little. The check earns its place on older layouts and
 * on setups that expose the artifacts.
 */
class MagiskArtifactsCheck(
    private val files: FileProbe,
    private val paths: List<String> = MAGISK_PATHS,
) : RootCheck {
    override val code = RootReasonCodes.MAGISK_ARTIFACTS
    override val isStrong = true

    override suspend fun run(): CheckOutcome =
        if (paths.any(files::exists)) CheckOutcome.Fired else CheckOutcome.Clear

    companion object {
        val MAGISK_PATHS =
            listOf(
                "/sbin/.magisk",
                "/data/adb/magisk",
                "/data/adb/modules",
                "/cache/magisk.log",
                "/data/local/tmp/magisk.apk",
                "/system/bin/magisk",
                "/system/xbin/magisk",
            )
    }
}
