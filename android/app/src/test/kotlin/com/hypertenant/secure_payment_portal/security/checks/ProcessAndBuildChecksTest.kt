package com.hypertenant.secure_payment_portal.security.checks

import com.hypertenant.secure_payment_portal.bridge.RootReasonCodes
import com.hypertenant.secure_payment_portal.security.probes.BuildInfo
import com.hypertenant.secure_payment_portal.security.probes.CommandResult
import com.hypertenant.secure_payment_portal.security.probes.CommandRunner
import com.hypertenant.secure_payment_portal.security.probes.SystemProperties
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

private class ScriptedRunner(private val result: CommandResult) : CommandRunner {
    val commands = mutableListOf<List<String>>()
    var timeout = -1L

    override suspend fun run(command: List<String>, timeoutMillis: Long): CommandResult {
        commands += command
        timeout = timeoutMillis
        return result
    }
}

class WhichSuCheckTest {
    private suspend fun run(result: CommandResult) = WhichSuCheck(ScriptedRunner(result)).run()

    @Test
    fun reportsTheWhichSuCode() {
        assertEquals(RootReasonCodes.WHICH_SU, WhichSuCheck(ScriptedRunner(CommandResult.Failed)).code)
    }

    @Test
    fun firesWhenWhichFindsAnSu() = runTest {
        assertEquals(CheckOutcome.Fired, run(CommandResult.Output("/system/xbin/su\n", 0)))
    }

    @Test
    fun isClearWhenWhichFindsNothing() = runTest {
        assertEquals(CheckOutcome.Clear, run(CommandResult.Output("", 1)))
    }

    @Test
    fun isClearWhenTheExitCodeSaysNotFoundEvenWithOutput() = runTest {
        assertEquals(CheckOutcome.Clear, run(CommandResult.Output("which: su: not found\n", 1)))
    }

    @Test
    fun isInconclusiveWhenTheCommandTimesOutOrCannotStart() = runTest {
        assertEquals(CheckOutcome.Inconclusive, run(CommandResult.TimedOut))
        assertEquals(CheckOutcome.Inconclusive, run(CommandResult.Failed))
    }

    @Test
    fun runsWhichSuWithTheTimeout() = runTest {
        val runner = ScriptedRunner(CommandResult.Output("", 1))

        WhichSuCheck(runner, timeoutMillis = 1_500).run()

        assertEquals(listOf(listOf("which", "su")), runner.commands)
        assertEquals(1_500L, runner.timeout)
    }
}

class TestKeysCheckTest {
    private fun tags(value: String?) = object : BuildInfo {
        override val tags = value
    }

    @Test
    fun reportsTheTestKeysCode() {
        assertEquals(RootReasonCodes.TEST_KEYS, TestKeysCheck(tags(null)).code)
    }

    @Test
    fun isClearForReleaseKeys() = runTest {
        assertEquals(CheckOutcome.Clear, TestKeysCheck(tags("release-keys")).run())
    }

    @Test
    fun firesForTestKeysAlone() = runTest {
        assertEquals(CheckOutcome.Fired, TestKeysCheck(tags("test-keys")).run())
    }

    @Test
    fun firesWhenTestKeysIsOneOfSeveralTags() = runTest {
        assertEquals(CheckOutcome.Fired, TestKeysCheck(tags("dev-keys,test-keys")).run())
    }

    @Test
    fun isInconclusiveWhenTheTagsCannotBeRead() = runTest {
        assertEquals(CheckOutcome.Inconclusive, TestKeysCheck(tags(null)).run())
    }
}

class DebuggableBuildCheckTest {
    private fun props(vararg values: Pair<String, String?>) = object : SystemProperties {
        private val map = mapOf(*values)

        override suspend fun get(name: String): String? = map[name]
    }

    @Test
    fun reportsTheDebuggableBuildCode() {
        assertEquals(RootReasonCodes.DEBUGGABLE_BUILD, DebuggableBuildCheck(props()).code)
    }

    @Test
    fun isClearForAProductionBuild() = runTest {
        val production = props("ro.debuggable" to "0", "ro.secure" to "1")

        assertEquals(CheckOutcome.Clear, DebuggableBuildCheck(production).run())
    }

    @Test
    fun firesWhenTheSystemIsDebuggable() = runTest {
        val debuggable = props("ro.debuggable" to "1", "ro.secure" to "1")

        assertEquals(CheckOutcome.Fired, DebuggableBuildCheck(debuggable).run())
    }

    @Test
    fun firesWhenTheSystemIsNotSecure() = runTest {
        val insecure = props("ro.debuggable" to "0", "ro.secure" to "0")

        assertEquals(CheckOutcome.Fired, DebuggableBuildCheck(insecure).run())
    }

    @Test
    fun isInconclusiveWhenNeitherPropertyCanBeRead() = runTest {
        assertEquals(CheckOutcome.Inconclusive, DebuggableBuildCheck(props()).run())
    }

    @Test
    fun oneReadableBenignPropertyIsEnoughForAClearResult() = runTest {
        assertEquals(
            CheckOutcome.Clear,
            DebuggableBuildCheck(props("ro.debuggable" to "0")).run(),
        )
        assertEquals(CheckOutcome.Clear, DebuggableBuildCheck(props("ro.secure" to "1")).run())
    }

    @Test
    fun aFiringPropertyWinsEvenIfTheOtherCannotBeRead() = runTest {
        assertEquals(
            CheckOutcome.Fired,
            DebuggableBuildCheck(props("ro.debuggable" to "1")).run(),
        )
    }
}
