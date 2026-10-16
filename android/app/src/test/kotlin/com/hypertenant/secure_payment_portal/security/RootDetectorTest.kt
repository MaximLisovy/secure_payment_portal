package com.hypertenant.secure_payment_portal.security

import com.hypertenant.secure_payment_portal.security.checks.CheckOutcome
import com.hypertenant.secure_payment_portal.security.checks.RootCheck
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.system.measureTimeMillis
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.After

private class FakeCheck(
    override val code: String,
    private val outcome: suspend () -> CheckOutcome,
) : RootCheck {
    constructor(code: String, fixed: CheckOutcome) : this(code, { fixed })

    override var isStrong = true

    override suspend fun run(): CheckOutcome = outcome()
}

@OptIn(ExperimentalCoroutinesApi::class)
class RootDetectorTest {
    private val detectors = mutableListOf<RootDetector>()

    @After
    fun closeDetectors() = detectors.forEach { it.close() }

    private val failures = mutableListOf<String>()

    private fun TestScope.detector(vararg checks: RootCheck, timeout: Long = 2_000) =
        RootDetector(
            checks.toList(),
            dispatcher = StandardTestDispatcher(testScheduler),
            perCheckTimeoutMillis = timeout,
            onCheckFailed = { code, error -> failures += "$code:${error.javaClass.simpleName}" },
        ).also { detectors += it }

    @Test
    fun allProbeCombinationsPreserveConfidenceAndMonotonicEligibility() = runTest {
        val outcomes = listOf(CheckOutcome.Clear, CheckOutcome.Fired, CheckOutcome.Inconclusive)
        val reports = (0 until 729).associateWith { encoded ->
            var remaining = encoded
            val checks = (0 until 6).map { index ->
                val result = outcomes[remaining % 3]
                remaining /= 3
                FakeCheck("probe-$index", result).also { it.isStrong = index < 4 }
            }
            detector(*checks.toTypedArray()).detect()
        }
        fun allowed(report: RootReport) = report.state != Detection.UNKNOWN &&
            report.signals.none { it.removePrefix("probe-").toInt() < 4 }
        for ((encoded, report) in reports) {
            for (index in 0 until 6) {
                val place = Math.pow(3.0, index.toDouble()).toInt()
                val outcome = encoded / place % 3
                // Adding a signal, or losing either kind of conclusive result.
                val changes = if (outcome == 2) listOf(1) else listOf(1, 2)
                for (changed in changes) {
                    val next = reports.getValue(encoded + (changed - outcome) * place)
                    assertFalse("$encoded -> ${encoded + (changed - outcome) * place}",
                        !allowed(report) && allowed(next))
                }
            }
            if (report.state == Detection.DETECTED && report.signals.all {
                it.removePrefix("probe-").toInt() >= 4
            }) {
                assertTrue((0 until 4).all { index -> encoded / Math.pow(3.0, index.toDouble()).toInt() % 3 != 2 })
            }
        }
    }

    @Test(timeout = 5_000)
    fun aTrulyBlockingProbeDoesNotExtendTheAwaitDeadline() = runBlocking {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val detector = RootDetector(
            listOf(FakeCheck("blocking") {
                entered.countDown()
                // A finite safety limit makes a broken implementation fail,
                // rather than hanging the test runner indefinitely.
                release.await(2, TimeUnit.SECONDS)
                CheckOutcome.Fired
            }),
            dispatcher = Dispatchers.IO,
            perCheckTimeoutMillis = 200,
            onCheckFailed = { _, _ -> },
        )
        try {
            lateinit var report: RootReport
            val elapsed = measureTimeMillis { report = detector.detect() }
            assertEquals(0L, entered.count)
            assertEquals(RootReport(Detection.UNKNOWN, emptyList(), listOf("blocking")), report)
            assertTrue("blocking probe extended waiting to ${elapsed}ms", elapsed < 1_000)
            // The worker is still physically blocked when detection returns.
            assertEquals(1L, release.count)
        } finally {
            release.countDown()
            detector.close()
        }
    }

    @Test
    fun cleanWeakChecksWithInconclusiveStrongChecksAreUnknown() = runTest {
        val report = detector(
            FakeCheck("weak-tags", CheckOutcome.Clear).also { it.isStrong = false },
            FakeCheck("weak-build", CheckOutcome.Clear).also { it.isStrong = false },
            FakeCheck("strong", CheckOutcome.Inconclusive),
        ).detect()
        assertEquals(RootReport(Detection.UNKNOWN, emptyList(), listOf("strong")), report)
    }

    @Test
    fun cleanWeakChecksAloneAreUnknown() = runTest {
        assertEquals(Detection.UNKNOWN, detector(
            FakeCheck("weak", CheckOutcome.Clear).also { it.isStrong = false },
        ).detect().state)
    }

    @Test
    fun oneConclusiveStrongCheckCannotHideAnotherInconclusiveStrongCheck() = runTest {
        assertEquals(Detection.UNKNOWN, detector(
            FakeCheck("strong", CheckOutcome.Clear),
            FakeCheck("unavailable", CheckOutcome.Inconclusive),
            FakeCheck("weak", CheckOutcome.Clear).also { it.isStrong = false },
        ).detect().state)
    }

    @Test
    fun noSignalFiredAndAtLeastOneCheckRanClean_isNotDetected() = runTest {
        val report =
            detector(
                    FakeCheck("a", CheckOutcome.Clear),
                    FakeCheck("b", CheckOutcome.Clear),
                )
                .detect()

        assertEquals(RootReport(Detection.NOT_DETECTED, emptyList()), report)
    }

    @Test
    fun firedSignalsAreReportedInTheOrderOfTheChecks() = runTest {
        val report =
            detector(
                    FakeCheck("first", CheckOutcome.Fired),
                    FakeCheck("second", CheckOutcome.Clear),
                    FakeCheck("third", CheckOutcome.Fired),
                )
                .detect()

        assertEquals(RootReport(Detection.DETECTED, listOf("first", "third")), report)
    }

    @Test
    fun oneInconclusiveStrongCheckAmongCleanOnesIsUnknown() = runTest {
        val report =
            detector(
                    FakeCheck("which", CheckOutcome.Inconclusive),
                    FakeCheck("files", CheckOutcome.Clear),
                )
                .detect()

        assertEquals(Detection.UNKNOWN, report.state)
    }

    @Test
    fun aFiredSignalStillCountsWhenOthersAreInconclusive() = runTest {
        val report =
            detector(
                    FakeCheck("which", CheckOutcome.Inconclusive),
                    FakeCheck("files", CheckOutcome.Fired),
                )
                .detect()

        assertEquals(RootReport(Detection.DETECTED, listOf("files"), listOf("which")), report)
    }

    @Test
    fun whenEveryCheckIsInconclusiveItIsUnknown() = runTest {
        val report =
            detector(
                    FakeCheck("a", CheckOutcome.Inconclusive),
                    FakeCheck("b", CheckOutcome.Inconclusive),
                )
                .detect()

        assertEquals(RootReport(Detection.UNKNOWN, emptyList(), listOf("a", "b")), report)
    }

    @Test
    fun withNoChecksNothingWasVerified_itIsUnknown() = runTest {
        assertEquals(Detection.UNKNOWN, detector().detect().state)
    }

    @Test
    fun aCheckThatThrowsIsInconclusiveAndDoesNotAffectTheOthers() = runTest {
        val report =
            detector(
                    FakeCheck("boom") { throw IllegalStateException("secret path /x") },
                    FakeCheck("files", CheckOutcome.Fired),
                )
                .detect()

        assertEquals(RootReport(Detection.DETECTED, listOf("files"), listOf("boom")), report)
        assertEquals(listOf("boom:IllegalStateException"), failures)
    }

    @Test
    fun aCheckThatThrowsAloneMakesTheResultUnknown() = runTest {
        val report = detector(FakeCheck("boom") { error("x") }).detect()

        assertEquals(Detection.UNKNOWN, report.state)
    }

    @Test
    fun aCheckThatNeverFinishesIsCutOffAtTheTimeout() = runTest {
        val report =
            detector(
                    FakeCheck("hangs") {
                        delay(Long.MAX_VALUE)
                        CheckOutcome.Fired
                    },
                    FakeCheck("files", CheckOutcome.Clear),
                    timeout = 2_000,
                )
                .detect()

        assertEquals(RootReport(Detection.UNKNOWN, emptyList(), listOf("hangs")), report)
        assertEquals(2_000L, testScheduler.currentTime)
    }

    @Test
    fun checksRunTogether_theCallTakesAsLongAsTheSlowestOne() = runTest {
        val slow = { millis: Long ->
            suspend {
                delay(millis)
                CheckOutcome.Clear
            }
        }

        detector(FakeCheck("a", slow(1_000)), FakeCheck("b", slow(1_000)), FakeCheck("c", slow(800)))
            .detect()

        assertEquals(1_000L, testScheduler.currentTime)
    }

    @Test
    fun cancellingTheCallerCancelsTheDetection_itIsNotSwallowedAsAFailedCheck() = runTest {
        var started = false
        var finished = false
        val detector =
            detector(
                FakeCheck("slow") {
                    started = true
                    delay(10_000)
                    finished = true
                    CheckOutcome.Clear
                }
            )

        val job = launch { detector.detect() }
        runCurrent()
        assertTrue(started)
        job.cancel()
        advanceUntilIdle()

        assertTrue(job.isCancelled)
        assertFalse(finished)
        assertTrue("a cancelled check is not a failed one", failures.isEmpty())
    }

    @Test
    fun aTimeoutInsideACheckIsThatCheckFailing_notTheWholeDetectionCancelling() = runTest {
        val report =
            detector(
                    FakeCheck("inner") {
                        withTimeout(10) { delay(1_000) }
                        CheckOutcome.Fired
                    },
                    FakeCheck("files", CheckOutcome.Clear),
                )
                .detect()

        assertEquals(RootReport(Detection.UNKNOWN, emptyList(), listOf("inner")), report)
        assertEquals(listOf("inner:TimeoutCancellationException"), failures)
    }
}
