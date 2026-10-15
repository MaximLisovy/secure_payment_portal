package com.hypertenant.secure_payment_portal.security

import android.content.Context
import com.hypertenant.secure_payment_portal.security.checks.DebuggableBuildCheck
import com.hypertenant.secure_payment_portal.security.checks.MagiskArtifactsCheck
import com.hypertenant.secure_payment_portal.security.checks.RootCheck
import com.hypertenant.secure_payment_portal.security.checks.RootManagerPackageCheck
import com.hypertenant.secure_payment_portal.security.checks.SuBinaryCheck
import com.hypertenant.secure_payment_portal.security.checks.TestKeysCheck
import com.hypertenant.secure_payment_portal.security.checks.WhichSuCheck
import com.hypertenant.secure_payment_portal.security.probes.AndroidBuildInfo
import com.hypertenant.secure_payment_portal.security.probes.CommandSystemProperties
import com.hypertenant.secure_payment_portal.security.probes.JavaFileProbe
import com.hypertenant.secure_payment_portal.security.probes.PackageManagerProbe
import com.hypertenant.secure_payment_portal.security.probes.ProcessCommandRunner

/** The checks this app runs, wired to the real device. */
fun defaultRootChecks(context: Context): List<RootCheck> {
    val files = JavaFileProbe()
    val runner = ProcessCommandRunner()
    return listOf(
        SuBinaryCheck(files),
        MagiskArtifactsCheck(files),
        RootManagerPackageCheck(PackageManagerProbe(context.packageManager)),
        WhichSuCheck(runner),
        TestKeysCheck(AndroidBuildInfo()),
        DebuggableBuildCheck(CommandSystemProperties(runner)),
    )
}
