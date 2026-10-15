package com.hypertenant.secure_payment_portal.security.probes

/**
 * Read-only system properties. `android.os.SystemProperties` is a hidden API and reflection is out
 * (R8, hidden-API restrictions), so the supported way for an app is the `getprop` command.
 */
interface SystemProperties {
    /** The value, or null if it is unset or could not be read. */
    suspend fun get(name: String): String?
}

class CommandSystemProperties(
    private val runner: CommandRunner,
    private val timeoutMillis: Long = 2_000,
) : SystemProperties {
    override suspend fun get(name: String): String? =
        when (val result = runner.run(listOf("getprop", name), timeoutMillis)) {
            is CommandResult.Output ->
                result.stdout.trim().takeIf { result.exitCode == 0 && it.isNotEmpty() }
            CommandResult.TimedOut,
            CommandResult.Failed -> null
        }
}
