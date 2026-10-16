package com.hypertenant.secure_payment_portal.security.probes

import com.hypertenant.secure_payment_portal.security.Detection
import com.hypertenant.secure_payment_portal.security.RootDetector
import com.hypertenant.secure_payment_portal.security.checks.SuBinaryCheck
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class JavaFileProbeTest {
    @Test
    fun explicitAccessDenialIsNotReportedAsAbsent() {
        val files = JavaFileProbe { throw SecurityException("denied") }
        assertThrows(SecurityException::class.java) { files.exists("/protected/su") }
    }

    @Test
    fun deniedFileAccessReachesTheDetectorAsInconclusive() = runTest {
        val check = SuBinaryCheck(JavaFileProbe { throw SecurityException("denied") })
        val failures = mutableListOf<Throwable>()
        val detector = RootDetector(
            listOf(check),
            dispatcher = StandardTestDispatcher(testScheduler),
            onCheckFailed = { _, error -> failures += error },
        )
        try {
            val report = detector.detect()
            assertEquals(Detection.UNKNOWN, report.state)
            assertEquals(emptyList<String>(), report.signals)
            assertEquals(listOf(check.code), report.inconclusive)
            assertEquals(SecurityException::class.java, failures.single().javaClass)
        } finally {
            detector.close()
        }
    }

    @Test
    fun aDeniedPathNextToAPresentSuBinaryStillDetectsRoot() = runTest {
        val check = SuBinaryCheck(
            JavaFileProbe { path -> if (path == "/sbin/su") true else throw SecurityException("denied") },
        )
        val detector = RootDetector(listOf(check), dispatcher = StandardTestDispatcher(testScheduler))
        try {
            val report = detector.detect()
            assertEquals(Detection.DETECTED, report.state)
            assertEquals(listOf(check.code), report.signals)
            assertEquals(emptyList<String>(), report.inconclusive)
        } finally {
            detector.close()
        }
    }

    @Test
    fun ordinaryPresenceAndAbsenceArePreserved() {
        for (present in listOf(true, false)) {
            var seen: String? = null
            val files = JavaFileProbe { path -> seen = path; present }
            assertEquals(present, files.exists("/probe"))
            assertEquals("/probe", seen)
        }
    }
}
