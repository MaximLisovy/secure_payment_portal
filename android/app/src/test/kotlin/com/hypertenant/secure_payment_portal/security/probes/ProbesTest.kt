package com.hypertenant.secure_payment_portal.security.probes

import java.io.File
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test

/** These start real processes, so they need a POSIX system (a developer machine or CI). */
class ProcessCommandRunnerTest {
    private val runner = ProcessCommandRunner(pollMillis = 10)

    private fun requirePosix(vararg paths: String) =
        assumeTrue(paths.all { File(it).exists() })

    @Test
    fun capturesTheOutputAndTheExitCode() = runBlocking {
        requirePosix("/bin/echo")

        val result = runner.run(listOf("/bin/echo", "hello"), timeoutMillis = 5_000)

        assertEquals(CommandResult.Output("hello\n", 0), result)
    }

    @Test
    fun reportsANonZeroExitCode() = runBlocking {
        requirePosix("/bin/sh")

        val result = runner.run(listOf("/bin/sh", "-c", "exit 3"), timeoutMillis = 5_000)

        assertEquals(CommandResult.Output("", 3), result)
    }

    @Test
    fun aBinaryThatDoesNotExistFailsToStart() = runBlocking {
        val result = runner.run(listOf("/definitely/not/here"), timeoutMillis = 5_000)

        assertEquals(CommandResult.Failed, result)
    }

    @Test
    fun aCommandThatRunsTooLongIsCutOffAndEnded() = runBlocking {
        requirePosix("/bin/sleep")

        val started = System.nanoTime()
        val result = runner.run(listOf("/bin/sleep", "30"), timeoutMillis = 200)
        val tookMillis = (System.nanoTime() - started) / 1_000_000

        assertEquals(CommandResult.TimedOut, result)
        assertTrue("took ${tookMillis}ms, expected about 200", tookMillis in 150..5_000)
    }

    @Test
    fun cancellingTheCallerStopsTheWaitInsteadOfRunningToTheTimeout() = runBlocking {
        requirePosix("/bin/sleep")

        val started = System.nanoTime()
        val call =
            async(start = CoroutineStart.UNDISPATCHED) {
                runner.run(listOf("/bin/sleep", "30"), timeoutMillis = 60_000)
            }
        call.cancelAndJoin()
        val tookMillis = (System.nanoTime() - started) / 1_000_000

        assertTrue(call.isCancelled)
        assertFalse("returned only after $tookMillis ms", tookMillis > 5_000)
    }
}
