package com.hypertenant.secure_payment_portal.security.probes

import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runInterruptible

sealed interface CommandResult {
    /** The process ended in time. [stdout] holds its output, [exitCode] its exit code. */
    data class Output(val stdout: String, val exitCode: Int) : CommandResult

    data object TimedOut : CommandResult

    /** The process could not be started at all. */
    data object Failed : CommandResult
}

/** Runs a short command and waits for it, with a time limit. A port, so tests need no process. */
interface CommandRunner {
    suspend fun run(command: List<String>, timeoutMillis: Long): CommandResult
}

/**
 * Runs the command on `Dispatchers.IO`. It is meant for commands whose output is a line or two
 * (`which su`, `getprop name`): the output is read after the process ends, so a command that fills
 * the pipe buffer first would be reported as timed out.
 *
 * `Process.waitFor(long, TimeUnit)`, `isAlive` and `destroyForcibly` are API 26 and minSdk is 24, so
 * it polls `exitValue()` (API 1) and ends the process with `destroy()` (API 1). Cancelling the
 * coroutine interrupts the wait, and the process is destroyed in every case.
 */
class ProcessCommandRunner(private val pollMillis: Long = 25) : CommandRunner {
    override suspend fun run(command: List<String>, timeoutMillis: Long): CommandResult =
        runInterruptible(Dispatchers.IO) { runProcess(command, timeoutMillis) }

    private fun runProcess(command: List<String>, timeoutMillis: Long): CommandResult {
        val process =
            try {
                ProcessBuilder(command).redirectErrorStream(true).start()
            } catch (e: IOException) {
                return CommandResult.Failed
            }
        try {
            val deadline = System.nanoTime() + timeoutMillis * NANOS_PER_MILLI
            while (true) {
                try {
                    val exitCode = process.exitValue()
                    val stdout = process.inputStream.bufferedReader().use { it.readText() }
                    return CommandResult.Output(stdout, exitCode)
                } catch (e: IllegalThreadStateException) {
                    // Still running.
                }
                if (System.nanoTime() >= deadline) return CommandResult.TimedOut
                Thread.sleep(pollMillis)
            }
        } finally {
            process.destroy()
        }
    }

    private companion object {
        const val NANOS_PER_MILLI = 1_000_000L
    }
}
