package com.hypertenant.secure_payment_portal.security.probes

import java.io.File

/** Whether a path exists, as seen by this app. A port, so checks run in plain JVM tests. */
fun interface FileProbe {
    fun exists(path: String): Boolean
}

/**
 * An unprivileged app cannot see most protected paths, and `File.exists` answers false for both an
 * absent path and an unreadable one: a false result means "not visible to this app", not "absent
 * on the device". An explicit `SecurityException` is different: it says access was denied, so it
 * propagates and the check (see `outcomeFor`) ends inconclusive instead of reading as clear.
 */
class JavaFileProbe(
    private val pathExists: (String) -> Boolean = { File(it).exists() },
) : FileProbe {
    override fun exists(path: String): Boolean = pathExists(path)
}
