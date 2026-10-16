package com.hypertenant.secure_payment_portal.payment

import com.hypertenant.secure_payment_portal.testing.FakeMainThread
import com.hypertenant.secure_payment_portal.testing.RecordingResult
import io.flutter.plugin.common.MethodCall
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

private class ScriptedPermission(private val answer: suspend () -> PermissionResult) : NotificationPermission {
    override suspend fun request() = answer()
}

@OptIn(ExperimentalCoroutinesApi::class)
class PaymentMethodHandlerTest {
    private val result = RecordingResult()
    private val main = FakeMainThread(onMain = true)
    private val store = PaymentProgressStore()
    private val launched = mutableListOf<PaymentRequest>()
    private var launcherFails: Exception? = null

    private fun TestScope.handler(
        permission: NotificationPermission = ScriptedPermission { PermissionResult.GRANTED },
        scope: CoroutineScope = this,
    ) =
        PaymentMethodHandler(
            scope = scope,
            starter = PaymentStarter(store) { request ->
                launcherFails?.let { throw it }
                launched += request
            },
            store = store,
            permission = permission,
            mainThread = main,
        )

    private fun PaymentMethodHandler.call(method: String, arguments: Any? = null) =
        onMethodCall(MethodCall(method, arguments), result)

    private fun startArgs(
        paymentId: Any? = "bill-1",
        amountMinor: Any? = 1100,
        currency: Any? = "USD",
    ) =
        mapOf(
            "schemaVersion" to 2,
            "paymentId" to paymentId,
            "attemptId" to "attempt-1",
            "amountMinor" to amountMinor,
            "currency" to currency,
        )

    @Test
    fun snapshotReturnsOnlyTheMatchingAttemptWithoutMutatingTheStore() = runTest {
        val handler = handler()
        handler.call("startPayment", startArgs())
        store.reportProgress("attempt-1", 45)
        handler.call("getPaymentSnapshot", mapOf("schemaVersion" to 2, "attemptId" to "attempt-1"))
        assertTrue(result.replies.last().contains("state=running"))
        assertTrue(result.replies.last().contains("percent=45"))
        handler.call("getPaymentSnapshot", mapOf("schemaVersion" to 2, "attemptId" to "other"))
        assertTrue(result.replies.last().contains("state=idle"))
        assertEquals(PaymentProgress.Running("bill-1", 45, "attempt-1"), store.state.value)
        handler.call("getPaymentSnapshot", null)
        assertTrue(result.replies.last().startsWith("error(INVALID_ARGS,"))
    }

    @Test
    fun snapshotReadsEveryRetainedTerminalAndNeverAnotherAttempt() = runTest {
        val terminals = listOf<PaymentProgress>(
            PaymentProgress.Succeeded("bill-1", "tx", 1100, "USD", 1700000000000, "attempt-1"),
            PaymentProgress.Failed("declined", "bill-1", "attempt-1"),
            PaymentProgress.Cancelled("bill-1", "attempt-1"),
        )
        for (terminal in terminals) {
            val retained = PaymentProgressStore(terminal)
            assertEquals(terminal, retained.snapshot("attempt-1"))
            assertEquals(PaymentProgress.Idle, retained.snapshot("other"))
            assertEquals(terminal, retained.state.value)
        }
        assertEquals(PaymentProgress.Idle, PaymentProgressStore().snapshot("attempt-1"))
    }

    @Test
    fun startPaymentIsAcceptedOnceTheServiceIsStarted() = runTest {
        handler().call("startPayment", startArgs())

        assertEquals(listOf("success(null)"), result.replies)
        assertEquals(listOf(PaymentRequest("bill-1", 1100, "USD", "attempt-1")), launched)
        assertEquals(PaymentProgress.Running("bill-1", 0, "attempt-1"), store.state.value)
    }

    @Test
    fun startPaymentWithAnAmountThatIsNotPositiveIsInvalidArgs() = runTest {
        val handler = handler()

        handler.call("startPayment", startArgs(amountMinor = 0))
        handler.call("startPayment", startArgs(amountMinor = -5))
        handler.call("startPayment", "not a map")
        handler.call("startPayment", null)

        assertEquals(4, result.replies.size)
        assertTrue(result.replies.all { it.startsWith("error(INVALID_ARGS,") })
        assertTrue("nothing was claimed or started", launched.isEmpty() && store.state.value == PaymentProgress.Idle)
    }

    @Test
    fun aSecondStartWhileOneRunsIsAlreadyRunningAndTheFirstKeepsGoing() = runTest {
        val handler = handler()
        handler.call("startPayment", startArgs())
        store.reportProgress("attempt-1", 30)

        handler.call("startPayment", startArgs(paymentId = "bill-2"))

        assertEquals("error(ALREADY_RUNNING,A payment is already running.,null)", result.replies.last())
        assertEquals(1, launched.size)
        assertEquals(PaymentProgress.Running("bill-1", 30, "attempt-1"), store.state.value)
    }

    @Test
    fun aRefusedServiceStartIsStartNotAllowedAndLeavesNothingClaimed() = runTest {
        launcherFails = IllegalStateException("app is in the background")

        handler().call("startPayment", startArgs())

        assertTrue(result.replies.single().startsWith("error(START_NOT_ALLOWED,"))
        assertEquals(PaymentProgress.Idle, store.state.value)
    }

    @Test
    fun anOtherFailureToStartIsInternalWithoutDetails() = runTest {
        launcherFails = SecurityException("secret detail /data/x")

        handler().call("startPayment", startArgs())

        assertEquals("error(INTERNAL,The payment call failed.,null)", result.replies.single())
    }

    @Test
    fun cancelCancelsARunningPaymentAndAnswersOk() = runTest {
        val handler = handler()
        handler.call("startPayment", startArgs())

        handler.call("cancelPayment", mapOf("schemaVersion" to 2, "attemptId" to "attempt-1"))

        assertEquals("success(null)", result.replies.last())
        assertEquals(PaymentProgress.Cancelled("bill-1", "attempt-1"), store.state.value)
    }

    @Test
    fun aCancelWithoutAttemptIdentityFailsWithoutCancellingAnything() = runTest {
        val handler = handler()
        handler.call("startPayment", startArgs())
        handler.call("cancelPayment")
        assertTrue(result.replies.last().startsWith("error(INVALID_ARGS,"))
        assertEquals(PaymentProgress.Running("bill-1", 0, "attempt-1"), store.state.value)
    }

    @Test
    fun cancelWithNothingRunningIsAnOkNoOp() = runTest {
        val handler = handler()

        handler.call("cancelPayment", mapOf("schemaVersion" to 2, "attemptId" to "attempt-1"))
        handler.call("cancelPayment", mapOf("schemaVersion" to 2, "attemptId" to "attempt-1"))

        assertEquals(listOf("success(null)", "success(null)"), result.replies)
        assertEquals(PaymentProgress.Idle, store.state.value)
    }

    @Test
    fun theNotificationPermissionReturnsCompletionWithoutSendingItsAnswer() = runTest {
        for (answer in PermissionResult.entries) {
            val fresh = RecordingResult()
            handler(ScriptedPermission { answer })
                .onMethodCall(MethodCall("requestNotificationPermission", null), fresh)
            advanceUntilIdle()

            assertEquals(listOf("success(null)"), fresh.replies)
        }
    }

    @Test
    fun theReplyWaitsForTheUserAndTheCallDoesNotBlock() = runTest {
        val user = CompletableDeferred<PermissionResult>()
        handler(ScriptedPermission { user.await() }).call("requestNotificationPermission")
        runCurrent()
        assertTrue("the user has not answered yet", result.replies.isEmpty())

        user.complete(PermissionResult.DENIED)
        advanceUntilIdle()

        assertEquals(listOf("success(null)"), result.replies)
    }

    @Test
    fun aPermissionRequestThatBreaksIsADenialAndNeverFails() = runTest {
        handler(ScriptedPermission { throw IllegalStateException("no activity") }).call("requestNotificationPermission")
        advanceUntilIdle()

        assertEquals(listOf("success(null)"), result.replies)
    }

    @Test
    fun denialNeverStopsAPaymentFromStarting() = runTest {
        val handler = handler(ScriptedPermission { PermissionResult.DENIED })

        handler.call("requestNotificationPermission")
        advanceUntilIdle()
        handler.call("startPayment", startArgs())

        assertEquals(listOf("success(null)", "success(null)"), result.replies)
        assertTrue(store.state.value is PaymentProgress.Running)
    }

    @Test
    fun repliesAreOnTheMainThreadAndOnlyOnce() = runTest {
        main.onMain = false

        handler().call("startPayment", startArgs())
        assertTrue("nothing may be sent off the main thread", result.replies.isEmpty())

        main.runPosted()
        assertEquals(1, result.replies.size)
    }

    @Test
    fun anUnknownMethodIsNotImplemented() = runTest {
        handler().call("getSecurityStatus")

        assertEquals(listOf("notImplemented"), result.replies)
    }

    @Test
    fun whenTheEngineGoesAwayAWaitingPermissionCallIsNeverAnswered() = runTest {
        val scope = CoroutineScope(StandardTestDispatcher(testScheduler))
        val never = CompletableDeferred<PermissionResult>()
        handler(ScriptedPermission { never.await() }, scope = scope).call("requestNotificationPermission")
        testScheduler.runCurrent()

        scope.coroutineContext[Job]!!.cancel()
        advanceUntilIdle()

        assertTrue(result.replies.isEmpty())
    }
}
