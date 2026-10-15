package com.hypertenant.secure_payment_portal.security.probes

import android.os.Build

/** The parts of `android.os.Build` the checks read. */
interface BuildInfo {
    /** `Build.TAGS`, e.g. `release-keys` or `test-keys`. */
    val tags: String?

    /** `Build.TYPE`: `user`, `userdebug` or `eng`. */
    val type: String?
}

class AndroidBuildInfo : BuildInfo {
    override val tags: String? = Build.TAGS
    override val type: String? = Build.TYPE
}
