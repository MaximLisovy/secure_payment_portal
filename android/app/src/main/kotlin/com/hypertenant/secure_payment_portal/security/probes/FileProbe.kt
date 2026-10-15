package com.hypertenant.secure_payment_portal.security.probes

import java.io.File

/** Whether a path exists, as seen by this app. A port, so checks run in plain JVM tests. */
fun interface FileProbe {
    fun exists(path: String): Boolean
}

/**
 * An unprivileged app cannot see most protected paths: a denied path reads as absent, so a `false`
 * here means "not visible to this app", not "not on the device".
 */
class JavaFileProbe : FileProbe {
    override fun exists(path: String): Boolean =
        try {
            File(path).exists()
        } catch (e: SecurityException) {
            false
        }
}
