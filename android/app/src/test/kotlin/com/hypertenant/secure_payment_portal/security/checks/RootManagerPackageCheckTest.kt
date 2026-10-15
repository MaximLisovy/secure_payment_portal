package com.hypertenant.secure_payment_portal.security.checks

import com.hypertenant.secure_payment_portal.bridge.RootReasonCodes
import com.hypertenant.secure_payment_portal.security.probes.PackageProbe
import java.io.File
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class RootManagerPackageCheckTest {
    @Test
    fun reportsTheRootManagerCode() {
        assertEquals(
            RootReasonCodes.ROOT_MANAGER_PACKAGE,
            RootManagerPackageCheck({ false }).code,
        )
    }

    @Test
    fun isClearWhenNoManagerIsInstalled() = runTest {
        assertEquals(CheckOutcome.Clear, RootManagerPackageCheck({ false }).run())
    }

    @Test
    fun firesForEachKnownManager() = runTest {
        for (name in RootManagerPackages.ALL) {
            val installed = PackageProbe { it == name }
            assertEquals(name, CheckOutcome.Fired, RootManagerPackageCheck(installed).run())
        }
    }

    @Test
    fun asksAboutEveryPackageWhenNoneIsInstalled() = runTest {
        val asked = mutableListOf<String>()

        RootManagerPackageCheck({ asked += it; false }).run()

        assertEquals(RootManagerPackages.ALL, asked)
    }

    // On API 30+ a package that is not listed under <queries> reads as not installed, so a name that
    // is in the code but not in the manifest would silently never be found.
    @Test
    fun theManifestQueriesListTheSamePackagesAsTheCode() {
        val manifest = File("src/main/AndroidManifest.xml").readText()
        val queries = Regex("<queries>(.*?)</queries>", RegexOption.DOT_MATCHES_ALL)
            .find(manifest)!!
            .groupValues[1]
        val listed =
            Regex("<package\\s+android:name=\"([^\"]+)\"")
                .findAll(queries)
                .map { it.groupValues[1] }
                .toList()

        assertEquals(RootManagerPackages.ALL.sorted(), listed.sorted())
    }
}
