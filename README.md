# secure_payment_portal

Hyper-Tenant Secure Payment Portal: multi-brand payment confirmation module.

## Requirements

- Flutter 3.41.x (Dart 3.11.5, see `environment.sdk` in `pubspec.yaml`).
- Android SDK 36.
- **JDK 17–21** for Android builds. JDK 25 is known to fail: Gradle configuration stops with
  `IllegalArgumentException: 25.0.1` because the Kotlin Gradle plugin (2.2.20) cannot parse that version.
  - Point Flutter at a supported JDK once: `flutter config --jdk-dir="<path to JDK 17–21>"`, then check with `flutter doctor -v`.
  - Raw Gradle calls (`./gradlew …`, e.g. Kotlin unit tests) do not read that setting. Prefix them for that command:
    `JAVA_HOME="<path to JDK 17–21>" ./gradlew …`.

## Brands (flavors)

One codebase, one Android flavor per brand. The flavor name is the brand id.

| Flavor | Application id | Launcher label |
|---|---|---|
| `retail` | `com.hypertenant.secure_payment_portal.retail` | Retail Shop |
| `utility` | `com.hypertenant.secure_payment_portal.utility` | Utility Pay |

`--flavor` is required. A plain `flutter run` or `flutter build apk` fails, because no flavor-less APK exists.

```bash
flutter run --flavor retail
flutter build apk --debug --flavor retail
flutter build apk --debug --flavor utility
```

The APKs land in `build/app/outputs/flutter-apk/` as `app-<flavor>-<mode>.apk`.
