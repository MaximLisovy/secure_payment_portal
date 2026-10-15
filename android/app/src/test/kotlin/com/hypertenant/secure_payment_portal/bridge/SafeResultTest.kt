package com.hypertenant.secure_payment_portal.bridge

import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

private class RecordingResult : MethodChannel.Result {
    val replies = mutableListOf<String>()

    @Synchronized
    override fun success(result: Any?) {
        replies += "success($result)"
    }

    @Synchronized
    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        replies += "error($errorCode,$errorMessage,$errorDetails)"
    }

    @Synchronized
    override fun notImplemented() {
        replies += "notImplemented"
    }
}

private class FakeMainThread(var onMain: Boolean) : MainThread {
    val posted = mutableListOf<() -> Unit>()

    override fun isCurrent() = onMain

    override fun post(block: () -> Unit) {
        posted += block
    }

    fun runPosted() {
        val pending = posted.toList()
        posted.clear()
        pending.forEach { it() }
    }
}

class SafeResultTest {
    private val delegate = RecordingResult()
    // Written from several threads in one test, so it must be thread-safe.
    private val duplicates = CopyOnWriteArrayList<String>()

    private fun safe(mainThread: MainThread) =
        SafeResult(delegate, mainThread) { duplicates += it }

    @Test
    fun repliesAtOnceWhenAlreadyOnTheMainThread() {
        safe(FakeMainThread(onMain = true)).success("ok")

        assertEquals(listOf("success(ok)"), delegate.replies)
    }

    @Test
    fun passesAnErrorAndNotImplementedThrough() {
        safe(FakeMainThread(onMain = true)).error("UNAVAILABLE", "no activity", null)
        safe(FakeMainThread(onMain = true)).notImplemented()

        assertEquals(
            listOf("error(UNAVAILABLE,no activity,null)", "notImplemented"),
            delegate.replies,
        )
    }

    @Test
    fun postsToTheMainThreadWhenCalledFromAnotherThread() {
        val main = FakeMainThread(onMain = false)

        safe(main).success("ok")

        assertTrue("nothing may be sent off the main thread", delegate.replies.isEmpty())
        main.runPosted()
        assertEquals(listOf("success(ok)"), delegate.replies)
    }

    @Test
    fun ignoresASecondReplyAndSaysSo() {
        val result = safe(FakeMainThread(onMain = true))

        result.success("first")
        result.success("second")
        result.error("INTERNAL", null, null)
        result.notImplemented()

        assertEquals(listOf("success(first)"), delegate.replies)
        assertEquals(3, duplicates.size)
    }

    @Test
    fun aSecondReplyBeforeThePostedOneRunsIsStillIgnored() {
        val main = FakeMainThread(onMain = false)
        val result = safe(main)

        result.success("first")
        result.success("second")
        main.runPosted()

        assertEquals(listOf("success(first)"), delegate.replies)
        assertEquals(1, duplicates.size)
    }

    @Test
    fun exactlyOneOfManyConcurrentRepliesGetsThrough() {
        val result = safe(FakeMainThread(onMain = true))
        val pool = Executors.newFixedThreadPool(8)
        val start = CountDownLatch(1)
        val done = CountDownLatch(8)
        repeat(8) { index ->
            pool.execute {
                start.await()
                result.success(index)
                done.countDown()
            }
        }

        start.countDown()
        assertTrue(done.await(5, TimeUnit.SECONDS))
        pool.shutdown()

        assertEquals(1, delegate.replies.size)
        assertEquals(7, duplicates.size)
    }
}
