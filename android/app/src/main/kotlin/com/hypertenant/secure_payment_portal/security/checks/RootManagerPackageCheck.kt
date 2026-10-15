package com.hypertenant.secure_payment_portal.security.checks

import com.hypertenant.secure_payment_portal.bridge.RootReasonCodes
import com.hypertenant.secure_payment_portal.security.probes.PackageProbe

/** A known root manager is installed. Strong signal. */
class RootManagerPackageCheck(
    private val packages: PackageProbe,
    private val names: List<String> = RootManagerPackages.ALL,
) : RootCheck {
    override val code = RootReasonCodes.ROOT_MANAGER_PACKAGE

    override suspend fun run(): CheckOutcome =
        if (names.any(packages::isInstalled)) CheckOutcome.Fired else CheckOutcome.Clear
}
