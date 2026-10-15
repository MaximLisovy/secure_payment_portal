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
}
