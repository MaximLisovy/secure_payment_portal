package com.hypertenant.secure_payment_portal.security.checks

import com.hypertenant.secure_payment_portal.bridge.RootReasonCodes
import com.hypertenant.secure_payment_portal.security.probes.CommandResult
import com.hypertenant.secure_payment_portal.security.probes.CommandRunner

/**
 * `which su` finds a `su` anywhere on the shell's PATH, including places the path list does not
 * know. Strong signal. A command that cannot run or does not finish in time is inconclusive, not
 * clean.
 */
class WhichSuCheck(
    private val runner: CommandRunner,
    private val timeoutMillis: Long = 2_000,
) : RootCheck {
    override val code = RootReasonCodes.WHICH_SU
    override val isStrong = true

    override suspend fun run(): CheckOutcome =
        when (val result = runner.run(listOf("which", "su"), timeoutMillis)) {
            is CommandResult.Output ->
                if (result.exitCode == 0 && result.stdout.isNotBlank()) {
                    CheckOutcome.Fired
                } else {
                    CheckOutcome.Clear
                }
            CommandResult.TimedOut,
            CommandResult.Failed -> CheckOutcome.Inconclusive
        }
}
