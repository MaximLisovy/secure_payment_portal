import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The brands this app ships, one entry per Android flavor: android/brands.json. The flavor name is
// the brand id in Dart (`appFlavor`), so every id must also be registered in
// lib/app/brand/brand_registry.dart; test/brands/brands_manifest_test.dart keeps the two in step.
// Adding a brand adds an entry there, not code here.
val brands: List<Map<String, String>> =
    @Suppress("UNCHECKED_CAST")
    (JsonSlurper().parse(rootProject.file("brands.json")) as List<Map<String, String>>)

check(brands.isNotEmpty()) { "android/brands.json lists no brand." }
brands.forEach { brand ->
    val id = brand["id"]
    check(id != null && Regex("[a-z][a-z0-9]*").matches(id)) {
        "android/brands.json: \"id\" must be lowercase letters and digits, starting with a letter: $brand"
    }
    check(brand["applicationIdSuffix"] == ".$id") {
        "android/brands.json: the applicationIdSuffix of \"$id\" must be \".$id\": $brand"
    }
    check(!brand["displayName"].isNullOrBlank()) {
        "android/brands.json: \"$id\" needs a displayName: $brand"
    }
    check(file("src/$id/res/mipmap-anydpi-v26/ic_launcher.xml").exists()) {
        "android/app/src/$id/res has no launcher icon. Every brand brings its own: see \"Add a brand\" in the README."
    }
}
check(brands.map { it.getValue("id") }.toSet().size == brands.size) {
    "android/brands.json lists a brand id twice."
}

android {
    namespace = "com.hypertenant.secure_payment_portal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        // Explicit: the flavor `app_name` resValues below depend on it.
        resValues = true
    }

    defaultConfig {
        // The base application id. Each brand flavor appends its own suffix from brands.json, so the
        // installed ids are com.hypertenant.secure_payment_portal.<brand> and both brands can be
        // installed side by side.
        applicationId = "com.hypertenant.secure_payment_portal"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // One flavor per entry of brands.json. Native code stays brand-agnostic.
    flavorDimensions += "brand"
    productFlavors {
        brands.forEach { brand ->
            create(brand.getValue("id")) {
                dimension = "brand"
                applicationIdSuffix = brand.getValue("applicationIdSuffix")
                resValue("string", "app_name", brand.getValue("displayName"))
            }
        }
    }

    testOptions {
        unitTests.all {
            // Some tests read the manifest, and the files it points to, from source
            // (src/test/.../manifest). Declared as inputs so editing them re-runs the tests; otherwise
            // Gradle reports the task up to date and a broken manifest would pass on a stale result.
            it.inputs.file("src/main/AndroidManifest.xml").withPropertyName("appManifest")
            it.inputs.file("src/main/res/xml/data_extraction_rules.xml").withPropertyName("dataExtractionRules")
            // A failing JVM test should say why in the Gradle output, not only in the report file.
            it.testLogging {
                events("failed")
                exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
            }
        }
    }

    buildTypes {
        release {
            // Release builds are signed with the debug keys, on purpose: this repository holds no
            // keystore and no secret, so anyone can build and install a release APK. These APKs are for
            // review, not for a store. A store release signs with its own key, supplied outside the
            // repository (see "Release signing" in the README).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// The native logic is brand-agnostic and every flavor compiles the same sources, so the unit tests of
// the first brand cover it. This name keeps the Definition of Done command free of a brand:
//   JAVA_HOME=<JDK 21> ./gradlew testDebugUnitTest
tasks.register("testDebugUnitTest") {
    group = "verification"
    description = "Runs the JVM unit tests (flavor-independent)."
    val first = brands.first().getValue("id").replaceFirstChar { it.uppercase() }
    dependsOn("test${first}DebugUnitTest")
}

dependencies {
    // core-ktx 1.19 needs compileSdk 37 and AGP 9.1; 1.18 is the newest that fits compileSdk 36 / AGP 8.11.
    implementation("androidx.core:core-ktx:1.18.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.11.0")
}
