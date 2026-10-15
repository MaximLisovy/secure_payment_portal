package com.hypertenant.secure_payment_portal.security.checks

/**
 * Packages of well-known root managers. The same names must be listed under `<queries>` in the
 * manifest, or the check cannot see them on API 30+; a unit test compares the two.
 *
 * Magisk can hide itself under a random package name, so a clean result proves nothing.
 */
object RootManagerPackages {
    val ALL =
        listOf(
            "com.topjohnwu.magisk",
            "me.weishu.kernelsu",
            "eu.chainfire.supersu",
            "com.noshufou.android.su",
            "com.koushikdutta.superuser",
            "com.thirdparty.superuser",
            "com.yellowes.su",
            "com.kingouser.com",
            "com.zachspong.temprootremovejb",
            "com.ramdroid.appquarantine",
        )
}
