package com.hypertenant.secure_payment_portal.security

import com.hypertenant.secure_payment_portal.security.checks.CheckOutcome
import com.hypertenant.secure_payment_portal.security.checks.RootCheck
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
    private val failures = mutableListOf<String>()

    private fun TestScope.detector(vararg checks: RootCheck, timeout: Long = 2_000) =
        RootDetector(
            checks.toList(),
            dispatcher = StandardTestDispatcher(testScheduler),
            perCheckTimeoutMillis = timeout,
            onCheckFailed = { code, error -> failures += "$code:${error.javaClass.simpleName}" },
        )

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
    fun oneConclusiveStrongCheckSufficesEvenWhenOthersCannotRun() = runTest {
        assertEquals(Detection.NOT_DETECTED, detector(
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
    fun oneInconclusiveCheckAmongCleanOnesDoesNotMakeItUnknown() = runTest {
        val report =
            detector(
                    FakeCheck("which", CheckOutcome.Inconclusive),
                    FakeCheck("files", CheckOutcome.Clear),
                )
                .detect()

        assertEquals(Detection.NOT_DETECTED, report.state)
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

        assertEquals(RootReport(Detection.NOT_DETECTED, emptyList(), listOf("hangs")), report)
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

        assertEquals(RootReport(Detection.NOT_DETECTED, emptyList(), listOf("inner")), report)
        assertEquals(listOf("inner:TimeoutCancellationException"), failures)
    }
}
