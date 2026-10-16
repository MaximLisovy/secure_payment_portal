package com.hypertenant.secure_payment_portal.security.checks

import com.hypertenant.secure_payment_portal.bridge.RootReasonCodes
import com.hypertenant.secure_payment_portal.security.probes.FileProbe
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

private fun filesThat(vararg existing: String) = FileProbe { it in existing }

class SuBinaryCheckTest {
    @Test
    fun reportsTheSuBinaryCode() {
        assertEquals(RootReasonCodes.SU_BINARY, SuBinaryCheck(filesThat()).code)
    }

    @Test
    fun isClearWhenNoKnownPathExists() = runTest {
        assertEquals(CheckOutcome.Clear, SuBinaryCheck(filesThat("/system/bin/ls")).run())
    }

    @Test
    fun firesForEachKnownPath() = runTest {
        for (path in SuBinaryCheck.SU_PATHS) {
            assertEquals(path, CheckOutcome.Fired, SuBinaryCheck(filesThat(path)).run())
        }
    }

    @Test
    fun looksAtEveryPathItIsGiven() = runTest {
        val asked = mutableListOf<String>()
        val check = SuBinaryCheck({ asked += it; false }, listOf("/a", "/b", "/c"))

        check.run()

        assertEquals(listOf("/a", "/b", "/c"), asked)
    }

    @Test
    fun theDefaultListCoversTheCommonLocations() {
        assertTrue("/system/xbin/su" in SuBinaryCheck.SU_PATHS)
        assertTrue("/sbin/su" in SuBinaryCheck.SU_PATHS)
        assertEquals(SuBinaryCheck.SU_PATHS.size, SuBinaryCheck.SU_PATHS.toSet().size)
    }
}

class MagiskArtifactsCheckTest {
    @Test
    fun reportsTheMagiskCode() {
        assertEquals(RootReasonCodes.MAGISK_ARTIFACTS, MagiskArtifactsCheck(filesThat()).code)
    }

    @Test
    fun isClearWhenNothingIsThere() = runTest {
        assertEquals(CheckOutcome.Clear, MagiskArtifactsCheck(filesThat()).run())
    }

    @Test
    fun firesForEachKnownPath() = runTest {
        for (path in MagiskArtifactsCheck.MAGISK_PATHS) {
            assertEquals(path, CheckOutcome.Fired, MagiskArtifactsCheck(filesThat(path)).run())
        }
    }
}

/** A probe that is denied on some paths, and answers for the others. */
private fun filesDenied(denied: Set<String>, vararg existing: String) =
    FileProbe { path ->
        if (path in denied) throw SecurityException("denied")
        path in existing
    }

class DeniedFileAccessTest {
    private val paths = listOf("/a", "/b", "/c")

    @Test
    fun aPathThatExistsAfterADeniedOneStillFires() = runTest {
        val check = SuBinaryCheck(filesDenied(setOf("/a"), "/c"), paths)

        assertEquals(CheckOutcome.Fired, check.run())
    }

    @Test
    fun aDeniedPathWithNothingFoundIsInconclusive() = runTest {
        val check = MagiskArtifactsCheck(filesDenied(setOf("/b")), paths)

        assertThrows(SecurityException::class.java) { runBlocking { check.run() } }
    }

    @Test
    fun everyPathIsProbedEvenAfterADenial() = runTest {
        val asked = mutableListOf<String>()
        val check = SuBinaryCheck({ asked += it; throw SecurityException("denied") }, paths)

        assertThrows(SecurityException::class.java) { runBlocking { check.run() } }
        assertEquals(paths, asked)
    }
}
