package com.hypertenant.secure_payment_portal.security

import com.hypertenant.secure_payment_portal.security.checks.CheckOutcome
import com.hypertenant.secure_payment_portal.security.checks.RootCheck
import com.hypertenant.secure_payment_portal.testing.FakeMainThread
import com.hypertenant.secure_payment_portal.testing.FakeRecordingSource
import com.hypertenant.secure_payment_portal.testing.FakeWindow
import com.hypertenant.secure_payment_portal.testing.RecordingResult
import io.flutter.plugin.common.MethodCall
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

private class Check(override val code: String, private val run: suspend () -> CheckOutcome) :
    RootCheck {
    constructor(code: String, fixed: CheckOutcome) : this(code, { fixed })

    override val isStrong = true

    override suspend fun run() = run.invoke()
}

@OptIn(ExperimentalCoroutinesApi::class)
class SecurityMethodHandlerTest {
    private val result = RecordingResult()
    private val main = FakeMainThread(onMain = true)
    private val window = FakeWindow()
    private val source = FakeRecordingSource(Detection.NOT_DETECTED)
    private val controller = SecureWindowController()
    private val monitor = ScreenRecordingMonitor()
    private val logged = mutableListOf<String>()

    private fun TestScope.handler(
        vararg checks: RootCheck,
        scope: CoroutineScope = this,
    ): SecurityMethodHandler =
        SecurityMethodHandler(
            scope = scope,
            rootDetector =
                RootDetector(
                    checks.toList(),
                    dispatcher = StandardTestDispatcher(testScheduler),
                    onCheckFailed = { _, _ -> },
                ),
            windowController = controller,
            recordingMonitor = monitor,
            mainThread = main,
            log = { logged += it },
        )

    private fun SecurityMethodHandler.call(method: String) =
        onMethodCall(MethodCall(method, null), result)

    private val clean = Check("a", CheckOutcome.Clear)

    @Test
    fun getSecurityStatusAnswersWithTheWireMapOfWhatTheDeviceReports() = runTest {
        controller.attach(window)
        controller.enable()
        monitor.attach(source)
        source.state = Detection.DETECTED
        val handler = handler(Check("su_binary", CheckOutcome.Fired), clean)

        handler.call("getSecurityStatus")
        advanceUntilIdle()

        assertEquals(
            listOf(
                "success(" +
                    "{schemaVersion=2, root=detected, rootSignals=[su_binary], " +
                    "screenRecording=detected, windowProtection=active})"
            ),
            result.replies,
        )
    }

    @Test
    fun theWindowProtectionComesFromTheWindowNotFromWhatWasAsked() = runTest {
        controller.attach(window)
        controller.enable()
        window.flag = false
        val handler = handler(clean)

        handler.call("getSecurityStatus")
        advanceUntilIdle()

        assertTrue(result.replies.single().contains("windowProtection=inactive"))
    }

    @Test
    fun withoutAnActivityRecordingIsUnknownAndTheWindowIsNotProtected() = runTest {
        handler(clean).call("getSecurityStatus")
        advanceUntilIdle()

        val reply = result.replies.single()
        assertTrue(reply, reply.contains("screenRecording=unknown"))
        assertTrue(reply, reply.contains("windowProtection=inactive"))
    }

    @Test
    fun theStatusIsAnsweredOnceAndOnlyOnTheMainThread() = runTest {
        main.onMain = false
        handler(clean).call("getSecurityStatus")
        advanceUntilIdle()

        assertTrue("nothing may be sent off the main thread", result.replies.isEmpty())
        main.runPosted()
        assertEquals(1, result.replies.size)
    }

    @Test
    fun theStatusWaitsForTheRootChecksButTheCallReturnsAtOnce() = runTest {
        val slow =
            Check("slow") {
                delay(1_000)
                CheckOutcome.Clear
            }

        handler(slow).call("getSecurityStatus")
        assertTrue("the handler must not block the main thread", result.replies.isEmpty())

        advanceUntilIdle()
        assertEquals(1, result.replies.size)
        assertEquals(1_000L, testScheduler.currentTime)
    }

    @Test
    fun anUnexpectedFailureBecomesInternalWithoutDetails() = runTest {
        monitor.attach(
            object : ScreenRecordingSource {
                override fun start(onChange: (Detection) -> Unit): Detection =
                    throw IllegalStateException("secret /data/path")

                override fun stop() = Unit
            }
        )

        handler(clean).call("getSecurityStatus")
        advanceUntilIdle()

        assertEquals(
            listOf("error(INTERNAL,The security call failed.,null)"),
            result.replies,
        )
    }

    @Test
    fun enablingProtectsTheWindowAndAnswersOk() = runTest {
        controller.attach(window)

        handler(clean).call("enableSecureWindow")

        assertEquals(listOf("success(null)"), result.replies)
        assertTrue(window.flag)
    }

    @Test
    fun enablingWithNoActivityFailsAsUnavailableAndCountsNothing() = runTest {
        handler(clean).call("enableSecureWindow")

        assertEquals(
            listOf("error(UNAVAILABLE,There is no window to protect.,null)"),
            result.replies,
        )
        assertEquals(0, controller.holderCount)
    }

    @Test
    fun disablingBalancesAnEnableAndAnExtraOneIsHarmless() = runTest {
        controller.attach(window)
        val handler = handler(clean)

        handler.call("enableSecureWindow")
        handler.call("disableSecureWindow")
        handler.call("disableSecureWindow")

        assertEquals(listOf("success(null)", "success(null)"), result.replies.take(2))
        assertEquals(3, result.replies.size)
        assertEquals(false, window.flag)
    }

    @Test
    fun anUnknownMethodIsNotImplemented() = runTest {
        handler(clean).call("startPayment")

        assertEquals(listOf("notImplemented"), result.replies)
    }

    @Test
    fun whenTheEngineGoesAwayAWaitingCallIsNeverAnswered() = runTest {
        val scope = CoroutineScope(StandardTestDispatcher(testScheduler))
        val slow =
            Check("slow") {
                delay(10_000)
                CheckOutcome.Clear
            }
        handler(slow, scope = scope).call("getSecurityStatus")
        testScheduler.runCurrent()

        scope.coroutineContext[kotlinx.coroutines.Job]!!.cancel()
        advanceUntilIdle()

        assertTrue(result.replies.isEmpty())
    }

    @Test
    fun theDebugLineHoldsStatesAndCodesOnly() = runTest {
        handler(Check("su_binary", CheckOutcome.Fired)).call("getSecurityStatus")
        advanceUntilIdle()

        assertEquals(
            listOf(
                "status root=detected signals=[su_binary] inconclusive=[] recording=unknown window=inactive"
            ),
            logged,
        )
    }
}
