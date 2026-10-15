package com.hypertenant.secure_payment_portal.security.checks

import com.hypertenant.secure_payment_portal.bridge.RootReasonCodes
import com.hypertenant.secure_payment_portal.security.probes.BuildInfo
import com.hypertenant.secure_payment_portal.security.probes.CommandResult
import com.hypertenant.secure_payment_portal.security.probes.CommandRunner
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

private fun buildInfo(tags: String? = null, type: String? = null) =
    object : BuildInfo {
        override val tags = tags
        override val type = type
    }

class TestKeysCheckTest {
    @Test
    fun reportsTheTestKeysCode() {
        assertEquals(RootReasonCodes.TEST_KEYS, TestKeysCheck(buildInfo()).code)
    }

    @Test
    fun isClearForReleaseKeys() = runTest {
        assertEquals(CheckOutcome.Clear, TestKeysCheck(buildInfo(tags = "release-keys")).run())
    }

    @Test
    fun firesForTestKeysAlone() = runTest {
        assertEquals(CheckOutcome.Fired, TestKeysCheck(buildInfo(tags = "test-keys")).run())
    }

    @Test
    fun firesWhenTestKeysIsOneOfSeveralTags() = runTest {
        assertEquals(
            CheckOutcome.Fired,
            TestKeysCheck(buildInfo(tags = "dev-keys,test-keys")).run(),
        )
    }

    @Test
    fun isInconclusiveWhenTheTagsCannotBeRead() = runTest {
        assertEquals(CheckOutcome.Inconclusive, TestKeysCheck(buildInfo()).run())
    }
}

class DebuggableBuildCheckTest {
    @Test
    fun reportsTheDebuggableBuildCode() {
        assertEquals(RootReasonCodes.DEBUGGABLE_BUILD, DebuggableBuildCheck(buildInfo()).code)
    }

    @Test
    fun isClearForAProductionBuild() = runTest {
        assertEquals(CheckOutcome.Clear, DebuggableBuildCheck(buildInfo(type = "user")).run())
    }

    @Test
    fun firesForUserdebugAndEng() = runTest {
        assertEquals(CheckOutcome.Fired, DebuggableBuildCheck(buildInfo(type = "userdebug")).run())
        assertEquals(CheckOutcome.Fired, DebuggableBuildCheck(buildInfo(type = "eng")).run())
    }

    @Test
    fun anUnknownTypeIsNotClaimedToBeDebuggable() = runTest {
        assertEquals(CheckOutcome.Clear, DebuggableBuildCheck(buildInfo(type = "custom")).run())
    }

    @Test
    fun isInconclusiveWhenTheTypeCannotBeRead() = runTest {
        assertEquals(CheckOutcome.Inconclusive, DebuggableBuildCheck(buildInfo()).run())
    }
}
