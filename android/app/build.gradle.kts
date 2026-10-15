plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hypertenant.secure_payment_portal"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The flavor name is the brand id in Dart (`appFlavor`), so it must match the
    // id registered in lib/app/brand/brand_registry.dart. Native code stays brand-agnostic.
    flavorDimensions += "brand"
    productFlavors {
        create("retail") {
            dimension = "brand"
            applicationIdSuffix = ".retail"
            resValue("string", "app_name", "Retail Shop")
        }
        create("utility") {
            dimension = "brand"
            applicationIdSuffix = ".utility"
            resValue("string", "app_name", "Utility Pay")
        }
    }

    testOptions {
        unitTests.all {
            // A failing JVM test should say why in the Gradle output, not only in the report file.
            it.testLogging {
                events("failed")
                exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// The native logic is brand-agnostic and both flavors compile the same sources, so one flavor's
// unit tests cover it. This name keeps the Definition of Done command free of a brand:
//   JAVA_HOME=<JDK 17-21> ./gradlew testDebugUnitTest
tasks.register("testDebugUnitTest") {
    group = "verification"
    description = "Runs the JVM unit tests (flavor-independent)."
    dependsOn("testRetailDebugUnitTest")
}

dependencies {
    // core-ktx 1.19 needs compileSdk 37 and AGP 9.1; 1.18 is the newest that fits compileSdk 36 / AGP 8.11.
    implementation("androidx.core:core-ktx:1.18.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.11.0")
}
