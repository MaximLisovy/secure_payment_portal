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

## Platform support

- **Android** is the supported platform. Root and screen recording detection, the secure window and the payment
  foreground service are native Android code.
- **iOS is out of scope.** It has no native implementation, so root detection always resolves as `unknown`.
  The security policy is fail-closed for an unverifiable root, so payment confirmation is blocked there by design.
  The app still compiles, and the channels degrade to "unsupported" instead of crashing.

## Security policy

Whether a payment may be confirmed is decided by `SecurityPolicy` (pure Dart, `lib/features/security/domain/`).
Defaults:

| Device state | Decision |
|---|---|
| a strong root signal (su binary, Magisk, root manager) | blocked |
| only weak root signals (test keys, debuggable build) | allowed |
| root could not be verified | blocked (fail-closed) |
| screen recording in progress | blocked; lifts when the recording ends |
| screen recording state unknown (below Android 15) | allowed |

Weak signals are common on emulators and developer builds, so they do not block on their own. Each of these
choices is a constructor flag on the policy.

## Money and dates

Amounts are integer minor units in a `Money` value object, never `double`, and are formatted by `MoneyFormatter`
(`$1,234.50`, `-$10.80`, `¥1,200`). Receipts show UTC time (`2026-10-15 12:00 UTC`). Neither uses the `intl` package, so
**neither is locale-aware**: the grouping, symbol position and date order are fixed. Locale-aware formatting is a
`MoneyFormatter` swap away once `intl` is wanted.

## Demo scenarios (debug builds)

The Android side is built in later milestones; until then, and later whenever a device or backend is hard to put in a
given state, every source with a platform side can run on a **simulation**. In a debug or profile build the tune icon in
the app bar opens a panel where, per source (device security, payment processing), you pick *Real* or *Simulated*
and, for a simulated one, play a situation:

- a clean, rooted, weakly-rooted or unverifiable device;
- a screen recording that starts and stops while the screen is open;
- a payment that succeeds, is declined, or fails while processing;
- a bill backend that goes offline (the bill backend is simulated by design: there is no backend).

A mode switch or a changed device restarts the payment flow so it takes effect at once. A **SIMULATED** badge sits in the
app bar for as long as any source is simulated, **in every build mode**: a simulated build must not pass for a real one.

Real is the default as soon as a source has a real implementation, and a release build cannot leave it. The real
sources arrive with the native milestones, so a build before them runs fully simulated, and says so.
