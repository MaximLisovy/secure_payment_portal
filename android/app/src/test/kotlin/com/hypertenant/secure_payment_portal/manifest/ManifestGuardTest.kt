package com.hypertenant.secure_payment_portal.manifest

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.w3c.dom.Element

private const val ANDROID_NS = "http://schemas.android.com/apk/res/android"

/** The app manifest, read from source, so a mistake that only shows on a device fails here. */
private class AppManifest(path: String = "src/main/AndroidManifest.xml") {
    private val root: Element =
        DocumentBuilderFactory.newInstance()
            .apply { isNamespaceAware = true }
            .newDocumentBuilder()
            .parse(File(path))
            .documentElement

    fun androidAttr(element: Element, name: String): String? =
        element.getAttributeNS(ANDROID_NS, name).takeIf { it.isNotEmpty() }

    fun elements(tag: String, parent: Element = root): List<Element> =
        (0 until parent.getElementsByTagName(tag).length).map {
            parent.getElementsByTagName(tag).item(it) as Element
        }

    fun usesPermission(name: String): Element? =
        elements("uses-permission").firstOrNull { androidAttr(it, "name") == name }
}

class ManifestGuardTest {
    private val manifest = AppManifest()

    @Test
    fun theRecordingPermissionIsRequestedFromApi35Only() {
        val permission = manifest.usesPermission("android.permission.DETECT_SCREEN_RECORDING")

        assertNotNull(permission)
        assertEquals("35", manifest.androidAttr(permission!!, "minSdkVersion"))
    }

    @Test
    fun theForegroundServicePermissionIsDeclared() {
        assertNotNull(manifest.usesPermission("android.permission.FOREGROUND_SERVICE"))
    }

    @Test
    fun theNotificationPermissionIsRequestedFromApi33Only() {
        val permission = manifest.usesPermission("android.permission.POST_NOTIFICATIONS")

        assertNotNull(permission)
        assertEquals("33", manifest.androidAttr(permission!!, "minSdkVersion"))
    }

    // shortService needs only FOREGROUND_SERVICE. A type-specific permission here would mean the
    // type was changed without the rest, and an unneeded permission is a Play review question.
    @Test
    fun noTypeSpecificForegroundServicePermissionIsRequested() {
        val typed =
            manifest.elements("uses-permission").mapNotNull {
                manifest.androidAttr(it, "name")?.takeIf { name ->
                    name.startsWith("android.permission.FOREGROUND_SERVICE_")
                }
            }

        assertEquals(emptyList<String>(), typed)
    }

    @Test
    fun noPermissionBroaderThanTheAppNeedsIsRequested() {
        val names = manifest.elements("uses-permission").mapNotNull { manifest.androidAttr(it, "name") }

        assertEquals(
            setOf(
                "android.permission.DETECT_SCREEN_RECORDING",
                "android.permission.FOREGROUND_SERVICE",
                "android.permission.POST_NOTIFICATIONS",
            ),
            names.toSet(),
        )
    }

    private fun component(tag: String, name: String): Element? =
        manifest.elements(tag).firstOrNull { manifest.androidAttr(it, "name") == name }

    private fun hasIntentFilter(element: Element) = element.getElementsByTagName("intent-filter").length > 0

    @Test
    fun thePaymentServiceIsDeclaredNotExportedAndShortServiceAlone() {
        val service = component("service", ".payment.PaymentProcessingService")

        assertNotNull("without this the service cannot start", service)
        assertEquals("false", manifest.androidAttr(service!!, "exported"))
        // Alone: combined with another type the system ignores shortService and its rules.
        assertEquals(
            "a service without a type crashes on start from Android 14",
            "shortService",
            manifest.androidAttr(service, "foregroundServiceType"),
        )
        assertEquals(false, hasIntentFilter(service))
    }

    @Test
    fun theCancelReceiverIsDeclaredNotExportedAndWithoutAnIntentFilter() {
        val receiver = component("receiver", ".payment.PaymentCancelReceiver")

        assertNotNull("without this the notification's Cancel does nothing", receiver)
        assertEquals("false", manifest.androidAttr(receiver!!, "exported"))
        assertEquals(false, hasIntentFilter(receiver))
    }

    // The app keeps nothing worth backing up; switching it off keeps it that way if a cache is added.
    @Test
    fun theAppDoesNotAllowBackup() {
        val application = manifest.elements("application").single()

        assertEquals("false", manifest.androidAttr(application, "allowBackup"))
        // Android 12+ reads its own rules, and they must exclude every domain from both paths.
        assertEquals("@xml/data_extraction_rules", manifest.androidAttr(application, "dataExtractionRules"))
        val rules = File("src/main/res/xml/data_extraction_rules.xml").readText()
        for (path in listOf("cloud-backup", "device-transfer")) {
            val section = rules.substringAfter("<$path>").substringBefore("</$path>")
            for (domain in listOf("root", "file", "database", "sharedpref", "external")) {
                assertEquals("$path leaves $domain in", true, section.contains("<exclude domain=\"$domain\" />"))
            }
        }
    }

    @Test
    fun nothingButTheLauncherActivityIsExported() {
        val exported =
            listOf("activity", "service", "receiver", "provider")
                .flatMap { tag -> manifest.elements(tag).map { tag to it } }
                .filter { (_, element) -> manifest.androidAttr(element, "exported") == "true" }
                .map { (_, element) -> manifest.androidAttr(element, "name") }

        assertEquals(listOf(".MainActivity"), exported)
    }

    // A typo in a relative component name only shows when the system tries to start it.
    @Test
    fun everyComponentNamedInTheManifestIsAClassOfTheApp() {
        val names =
            listOf("activity", "service", "receiver")
                .flatMap { tag -> manifest.elements(tag) }
                .mapNotNull { manifest.androidAttr(it, "name") }
                .filter { it.startsWith(".") }

        assertEquals(setOf(".MainActivity", ".payment.PaymentProcessingService", ".payment.PaymentCancelReceiver"), names.toSet())
        for (name in names) {
            val path = "src/main/kotlin/com/hypertenant/secure_payment_portal/" + name.removePrefix(".").replace('.', '/') + ".kt"
            assertEquals("$name has no source at $path", true, File(path).exists())
        }
    }
}
