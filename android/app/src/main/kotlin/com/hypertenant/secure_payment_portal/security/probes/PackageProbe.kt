package com.hypertenant.secure_payment_portal.security.probes

import android.content.pm.PackageManager
import android.os.Build

/** Whether a package is installed and visible to this app. */
fun interface PackageProbe {
    fun isInstalled(packageName: String): Boolean
}

/**
 * On API 30+ a package is visible only if the manifest lists it under `<queries>`; an unlisted one
 * reads as not installed. The list of names lives in `RootManagerPackages` and is kept equal to the
 * manifest by a unit test.
 */
class PackageManagerProbe(private val packageManager: PackageManager) : PackageProbe {
    override fun isInstalled(packageName: String): Boolean =
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                // getPackageInfo(String, PackageInfoFlags): API 33.
                packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
}
