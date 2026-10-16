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

## Tests

```bash
flutter test                                  # Dart: domain, data, presentation, architecture rules
(cd android && JAVA_HOME="<path to JDK 17–21>" ./gradlew testDebugUnitTest)   # Kotlin: JVM unit tests
```

The Kotlin tests need no device or emulator: the root checks, the reference-counted secure window, the recording
monitor, the payment store and session, the notification throttle, a guard over the manifest and the channel handlers
run behind small ports. The logic is brand-agnostic and both flavors compile the same
sources, so `testDebugUnitTest` runs it once. What no automated test covers is Dart talking to the real Kotlin plugin;
that is checked on a device (see `docs/platform_channels.md`).

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
  The app still compiles, and the channels degrade to "unsupported" instead of crashing. The same holds for desktop and
  plain `flutter test`: the real security source is the default everywhere, and with no native side it refuses payment.
  In a debug build, switch Device security to *Simulated* in the demo panel to get a working screen there.

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

## The security scan

While the device is being checked, the security card shows a radar: a sweep that goes round once per period, with three
pulses staggered a third of a period apart. It is a `CustomPainter` (`lib/core/design_system/scan/`), and all of its
maths is a function of one number, the phase of the animation, documented in `scan_math.dart` (formulas, period, why it
repeats without a seam).

- **Each brand gets its own scan from its tokens, with no brand check.** `ScanStyle` reads the glow (`scanGlow`), the
  rings (`outlineSubtle`) and the pulse easing (`motion.standard`), and sets the period to four times `motion.slow`,
  held between 1.6 s and 3 s: Retail turns in 2.4 s with soft pulses, Utility in 1.6 s with quick ones. A new brand needs
  nothing extra.
- **It costs no rebuilds and one repaint layer.** A still backdrop and the moving part sit in two `RepaintBoundary`s; the
  moving painter listens to the animation itself. Frames rebuild no widget and repaint nothing else on the page, `paint()`
  allocates nothing, and the ticker exists only while the scan is on screen. With reduced motion the scan shows a still
  pose and nothing animates. The tests that prove it are listed in `.agents/rules/performance-custom-painter.md`.
- **The verdict waits for the sweep to go all the way round.** A real device check takes a fraction of a second, which
  would make the scan a flash that a release build never really shows. The flow therefore holds the verdict until the end
  of a revolution: `max(how long the check took, one period)`, rounded up to the end of the revolution it finished in.
  Pay is enabled 2.4 s after the check starts on Retail and 1.6 s on Utility, on any device that answers quickly; a slow
  check waits for the end of the revolution it lands in. The wait is the brand's own period, so there is no number to
  configure. It is not applied with reduced motion (nothing sweeps), not to the second check made when Pay is pressed,
  and not in tests, where the verdict is immediate. The one place it is wired for the app is `main()`.
- **To see it for longer** (a recording, a close look), switch Device security to *Simulated* in the demo panel and pick
  how long the check takes: 1.5 s, 5 s or 15 s. The panel's *Display* section also turns on Flutter's performance overlay.

Frame timing is measured on a device, in profile mode, for every registered brand, next to two references: Material's own
spinner, and a layer that draws one dot per frame (the least any animating layer costs on that device):

```bash
flutter drive --profile --no-dds --flavor retail -d <device id> \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/scan_performance_test.dart \
  --dart-define=DEVICE_NAME="<what to call the device>"
```

It takes about 6 minutes and writes `build/scan_performance/summary.md` (and `summary.json`, `raw.json`). It is not part
of `flutter test`. Emulator numbers are indicative only; the measured ones are in `docs/ai/AI_INSIGHT_REPORT.md` and
the phone run is in `docs/MANUAL_QA.md`.

## Manual QA and the demo video

What needs a person is collected in [`docs/MANUAL_QA.md`](docs/MANUAL_QA.md), one checklist grouped by milestone, to be
run once on a physical phone with a profile build. Findings that depend on it are marked *pending manual verification*
until then.

**The demo video is recorded from the emulator window with macOS screen capture** (Cmd+Shift+5, record the emulator
window), not from inside Android. `FLAG_SECURE` blacks out every capture made by Android itself (`adb screenrecord`, the
Screen record tile, `scrcpy`, the screenshot button) on every build mode, simulated included; macOS captures the window
from outside the guest, so the payment screen shows.

## Money and dates

Amounts are integer minor units in a `Money` value object, never `double`, and are formatted by `MoneyFormatter`
(`$1,234.50`, `-$10.80`, `¥1,200`). Receipts show UTC time (`2026-10-15 12:00 UTC`). Neither uses the `intl` package, so
**neither is locale-aware**: the grouping, symbol position and date order are fixed. Locale-aware formatting is a
`MoneyFormatter` swap away once `intl` is wanted.

## Demo scenarios (debug builds)

Whenever a device or backend is hard to put in a given state, every source with a platform side can run on a
**simulation**. In a debug or profile build the tune icon in
the app bar opens a panel where, per source (device security, payment processing), you pick *Real* or *Simulated*
and, for a simulated one, play a situation:

- a clean, rooted, weakly-rooted or unverifiable device;
- a screen recording that starts and stops while the screen is open;
- a payment that succeeds, is declined, or fails while processing;
- a bill backend that goes offline (the bill backend is simulated by design: there is no backend).

A mode switch or a changed device restarts the payment flow so it takes effect at once. A **SIMULATED** badge sits in the
app bar for as long as any source is simulated, **in every build mode**: a simulated build must not pass for a real one.

Real is the default as soon as a source has a real implementation, and a release build cannot leave it. Device
security has one (the Kotlin `SecurityPlugin`) and so does payment processing (the Kotlin foreground service), so a
default build runs on real sources and shows **no badge**; the badge appears only once something is switched to
Simulated. In Real mode the panel shows a read-only **Device reports** block: the root signals that fired, whether a
recording is detected, whether the window is protected.

**Real payment processing** is a foreground service of type `shortService` with a progress notification (generic text,
private on the lock screen, a Cancel action). On Android 13 and above the first payment asks for the notification
permission; denying it never stops a payment, it only means no notification. The native processing always succeeds
(20 steps of 400 ms); declined and failing payments are Simulated scenarios. The payment state lives in the process:
it survives the app being backgrounded or swiped away, not the process being killed (see
`docs/platform_channels.md` and the idempotency note in `docs/ai/AI_INSIGHT_REPORT.md`).

The simulation replaces the security **readings** only (root, recording, the scenarios), never the window: `FLAG_SECURE`
is applied through the real source in every mode, so the payment screen is black in a screenshot, a screen recording and
the recents list on every Android build, simulated or not. The simulation can still *report* a scenario, for example
"Screen protection available" switched off shows the "screen protection unavailable" block without removing any
protection. (A consequence: a screen recording made inside Android shows the payment page black; record the emulator
window from macOS instead, see "Manual QA and the demo video".)
