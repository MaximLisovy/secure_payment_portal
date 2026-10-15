package com.hypertenant.secure_payment_portal.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

private class FakeWindow : SecureWindowTarget {
    var flag = false
    val calls = mutableListOf<Boolean>()

    override val isSecure: Boolean
        get() = flag

    override fun setSecure(secure: Boolean) {
        calls += secure
        flag = secure
    }
}

class SecureWindowControllerTest {
    private val controller = SecureWindowController()
    private val window = FakeWindow()

    @Test
    fun withNoWindowNothingIsProtectedAndAnEnableFailsWithoutCounting() {
        assertEquals(WindowProtection.INACTIVE, controller.protection())

        assertFalse(controller.enable())

        assertEquals(0, controller.holderCount)
    }

    @Test
    fun theFlagGoesOnWithTheFirstEnableAndIsReportedActive() {
        controller.attach(window)

        assertTrue(controller.enable())

        assertEquals(listOf(true), window.calls)
        assertEquals(WindowProtection.ACTIVE, controller.protection())
    }

    @Test
    fun theFlagComesOffOnlyWhenEveryEnableIsBalanced() {
        controller.attach(window)
        controller.enable()
        controller.enable()

        controller.disable()
        assertTrue("one screen still needs it", window.flag)
        assertEquals(WindowProtection.ACTIVE, controller.protection())

        controller.disable()
        assertFalse(window.flag)
        assertEquals(WindowProtection.INACTIVE, controller.protection())
        assertEquals(listOf(true, false), window.calls)
    }

    @Test
    fun anExtraDisableIsIgnoredAndDoesNotCancelTheNextEnable() {
        controller.attach(window)
        controller.enable()
        controller.disable()
        controller.disable()
        controller.disable()
        assertEquals(0, controller.holderCount)

        controller.enable()
        assertTrue(window.flag)
        assertEquals(1, controller.holderCount)

        controller.disable()
        assertFalse("a single enable needs a single disable", window.flag)
    }

    @Test
    fun aDisableWithNothingToBalanceNeverTouchesTheWindow() {
        controller.attach(window)

        controller.disable()

        assertTrue(window.calls.isEmpty())
    }

    @Test
    fun aConfigChangeKeepsTheCountAndProtectsTheNewWindowAtOnce() {
        controller.attach(window)
        controller.enable()
        controller.detach()
        val recreated = FakeWindow()

        controller.attach(recreated)

        assertEquals(1, controller.holderCount)
        assertEquals("applied by attach, before anyone asks again", listOf(true), recreated.calls)
        assertEquals(WindowProtection.ACTIVE, controller.protection())
    }

    @Test
    fun aNewWindowIsLeftAloneWhenNobodyHoldsProtection() {
        controller.attach(window)
        controller.enable()
        controller.disable()
        controller.detach()
        val recreated = FakeWindow()

        controller.attach(recreated)

        assertTrue(recreated.calls.isEmpty())
        assertEquals(WindowProtection.INACTIVE, controller.protection())
    }

    @Test
    fun withTheWindowGoneProtectionIsInactiveEvenIfSomeoneHoldsIt() {
        controller.attach(window)
        controller.enable()

        controller.detach()

        assertEquals(1, controller.holderCount)
        assertEquals(WindowProtection.INACTIVE, controller.protection())
        assertFalse("an enable with no window must fail", controller.enable())
        assertEquals(1, controller.holderCount)
    }

    @Test
    fun aDisableWhileDetachedStillBalances() {
        controller.attach(window)
        controller.enable()
        controller.detach()

        controller.disable()
        val recreated = FakeWindow()
        controller.attach(recreated)

        assertEquals(0, controller.holderCount)
        assertTrue(recreated.calls.isEmpty())
    }

    @Test
    fun protectionIsReadFromTheWindowNotFromTheCount() {
        controller.attach(window)
        controller.enable()

        window.flag = false // something else cleared the flag

        assertEquals(WindowProtection.INACTIVE, controller.protection())
    }

    @Test
    fun anotherEnableReassertsAFlagThatWasCleared() {
        controller.attach(window)
        controller.enable()
        window.flag = false

        controller.enable()

        assertTrue(window.flag)
        assertEquals(WindowProtection.ACTIVE, controller.protection())
        assertEquals(2, controller.holderCount)
    }
}
