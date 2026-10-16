# Appendix D: Final review against the checklist

Part of the [AI Insight Report](../AI_INSIGHT_REPORT.md). The checklist is [`.agents/rules/review-checklist.md`](../../../.agents/rules/review-checklist.md),
run over the whole repository at the end of the last milestone, by the agent that wrote most of it. A claim that rests on
a test points to the test; one that rests on a search says what was searched.

✅ checked, as it should be. ⚠️ a deviation that stays, and why. ❌ found and fixed in this pass.

## Architecture

- ✅ **Dependency rule.** Domain is pure Dart, presentation and the app never import a data layer, a feature reaches another
  only through its barrel, fakes stay inside their seams: `test/architecture/layering_test.dart`.
- ✅ **Single reason to change, small files.** Production files remain small; payment flow timing and native worker coordination are extracted and tested separately. The original sizes were `payment_flow_notifier.dart` 226 and `PaymentProcessingService.kt` 195 lines before the review fixes.
  - ❌ The notifier had reached 243 lines when it took the scan dwell. The timing moved to `VerdictHold`, tested alone.
- ✅ **Open/Closed.** Payment sections go through `PaymentSectionRegistry` (a new section is a spec, a widget and one
  `.adding`), brands through the manifest and the registry. A scratch third brand needed nothing under `lib/features` or
  `lib/core` (see the multi-tenant section).
- ✅ **`Ref` stays out of domain and data** (searched: none), providers only wire.
- ✅ **Riverpod.** `build()` only returns the initial state (the flow starts in methods); 11 `ref.mounted` checks after awaits;
  `select` in 14 places; no `StateNotifier`, `StateProvider` or `ChangeNotifierProvider` (searched: none); retry is off at
  the root (`disableProviderRetry`).
- ✅ **Feature boundaries**: same layering test.

## Multi-tenant

- ✅ **No brand, flavor or app id checks outside `brand_registry.dart`**: layering test, and a search for `appFlavor` and the
  brand ids outside `lib/brands` and the registry (none).
- ✅ **No hard-coded colors, radii or durations in `features/` or `core/` widgets.** The only literals are
  `Colors.transparent` in the theme builders and the scan's alpha constants, which are documented maths, not brand values.
- ✅ **`ThemeExtension`s have real `copyWith` and `lerp`** (token tests, including the endpoints).
- ✅ **Brand #3 needs zero edits in `features/`.** Tried, not argued: a scratch third brand (a config file, a registry line, a
  manifest entry, an icon folder) passed all 844 tests at that moment and built an APK; its careless first colors were
  rejected by the contrast table (4.41:1 against 4.5:1). It also found two tests that were stricter than the rule (an exact
  brand list, a distinct bill per brand), which were relaxed so that adding a brand edits no test.

## Correctness and safety

- ✅ **Money is never a `double`** (searched; `Money` is integer minor units with an explicit currency).
- ✅ **Failures are typed and visible.** Sealed `Failure` families per feature, each mapped to a screen state, never a silent
  no-op. ❌ The one place errors could vanish was the data layer: nothing was logged. A `Logger` was added, and the failure
  mapper and the channel data sources now say what they swallow (below).
- ✅ **The security policy lives in domain and is tested** (`security_policy_test.dart`), including fail-closed.
- ✅ **No sensitive data in logs, no `print`.** `print` is banned in `lib` by a test, `dart:developer` is only imported by the
  logger, and the logging tests plant a card number in every native message and assert it never reaches a log. Kotlin logs
  an error class or a code, and its verbose log is on only in a debuggable build.
- ✅ **Null safety.** No `!` operator in `lib` (searched). `dynamic` appears only in a comment and in `ThemeExtension<dynamic>`
  (the framework's type). `late` only where initialisation order is guaranteed.

## Android native

- ✅ **Every channel call replies once, on main**, and no blocking work runs on main (`SafeResult` and the handlers' tests,
  including a concurrent-reply test). Coroutine scopes are cancelled in `onDestroy`/`detach`.
- ✅ **API-level guards.** Three `SDK_INT` guards and two `@RequiresApi`, each with the API level in a comment. Android Lint:
  no error. ❌ It flagged the API 34 foreground-type constant (documented suppression: `ServiceCompat` masks it below 34),
  an obsolete `drawable-v21` folder (merged) and backup settings (below). Two version notes remain on purpose (Gradle 8.14,
  core-ktx 1.18: pinned for AGP 8.11 and compileSdk 36).
- ✅ **No deprecated APIs in our Kotlin** (compiler warnings come only from Flutter's own Gradle plugin).
- ✅ **Foreground service.** `shortService` alone, user-initiated start, `START_NOT_STICKY`, `onTimeout`, throttled updates, a
  non-exported cancel receiver: `ManifestGuardTest` and the JVM tests; verified on an emulator (`docs/platform_channels.md`).
  ⚠️ The refused-start path and the three-minute timeout are covered by JVM tests only; they cannot be reproduced by hand.
- ✅ **Dart and Kotlin constants and `docs/platform_channels.md` are in step.** A test compares the two source files, and the wire fields are documented; schema v2 adds required attempt identity.
- ❌ **Backups.** `allowBackup` was left at its default. It is now `false`, with Android 12 data-extraction rules that
  exclude every domain; the manifest test checks both, and the rules file is a declared input of the unit tests (a stale
  Gradle result once let a broken manifest pass, which is why).

## Performance

- ✅ **The painter uses `repaint:` and `RepaintBoundary`**, with no `setState` per frame and no avoidable allocation in
  `paint()`; the tests are listed in [Appendix A](performance.md). The one other `setState` (the result view) runs once per
  result, and the demo panel's runs on a tap.
- ✅ **Rebuild scope is minimal**: `select`, small `Consumer` leaves, `MediaQuery.*Of`, `const`.
- ⚠️ **Measured on an emulator only.** Nothing is claimed for 90 or 120 Hz; the phone run is `M6-6`.

## Tests and tooling

- ✅ **New domain logic and notifiers have tests**, and the all-brands tests pass: 855 Dart tests and 220 Kotlin JVM tests (counted at the end, after the review fixes).
- ✅ **`dart format`, `flutter analyze` (zero issues), `flutter test`** are green, and both flavors build in debug and in
  release; both release APKs were installed and run on an emulator (scan shown, a payment completed, no crash, not
  debuggable). `dart fix --dry-run`: nothing to fix.
- ✅ **iOS still compiles** (`flutter build ios --simulator --no-codesign`).
- ✅ **CI** was validated with `actionlint`, and its `verify` and `build` jobs were run step by step in a clean clone.
  ❌ That found that a fresh clone has no `./gradlew` (Flutter git-ignores the wrapper), so the Kotlin step would have failed
  on the first push, and so would the README command. The official Gradle 8.14 wrapper is now committed, its jar checked
  against the checksum Gradle publishes and the distribution pinned by SHA-256.
- ❌ **Residue.** An unused `cupertino_icons` dependency and 59 lines of generated comments in `pubspec.yaml` were removed.
- ✅ **No `TODO` or `FIXME`** anywhere in the sources (searched). Every relative link and anchor in the documentation is
  checked by a test.

## AI-generated patterns the checklist names

| Pattern | Found? |
|---|---|
| branding by `if/else`, one giant theme class | no: tokens, four small extensions, a layering test |
| side effects in `build()`, `ref.watch` in callbacks, `StateNotifier` | no |
| `setState` driving an animation | no |
| channel replies from background threads, or twice | no: `SafeResult` |
| `GlobalScope` | no (searched) |
| a foreground service without a type, or started from the background | no: `shortService`, refusal mapped to a typed failure |
| `double` money | no |
| business logic in widgets | no: policy in domain, the dwell in a notifier |
| swallowed exceptions | **yes, until this pass**: errors were mapped but not logged. Fixed with the Logger |
| invented APIs or wrong API levels | yes, caught on the way: a `getprop` check that apps cannot read, `Process` methods that need API 26, a notification flag order that the device contradicted. All found by running on a device, not by review |

## What stays open

Everything that needs a person and a phone is in [Manual QA](../../MANUAL_QA.md) and has not been run: the notification
prompt and shade, the lock screen, API levels other than 36, how fast the scan feels (is Utility's 1.6 s too quick?), frame
timing on a 90 or 120 Hz screen, and whether the screen-recording callback fires under `FLAG_SECURE`. The wire contract stays
marked draft until then. The CI workflow has been validated but has not yet run on GitHub.

## Independent review and follow-up corrections

The initial checklist above records the earlier milestone's checks. Independent review subsequently reproduced cross-attempt corruption, stale Flutter confirmation, unrelated progress hiding a command rejection, a security snapshot taken before a permission prompt, overlapping window acquisitions and writable domain collections. The fixes and regressions are described in AI Insight Report section 3 and [working log](working_log.md) entries 09 onward. Existing device/profile results are historical; schema v2 and worker coordination have automated validation, with new device scenarios still pending in Manual QA.

Follow-up automated validation: 855 Dart tests and 220 Kotlin/JVM tests pass; formatting and Flutter analysis are clean, and Android Lint reports no errors. Current schema-v2 debug and release APKs were rebuilt for both brands. After the developer explicitly authorized Flutter to regenerate plugin registration, ordinary release build commands resolved the earlier stale integration_test registration failure without manual generated-file edits. The initial approval rejection and successful follow-up are recorded in [working log](working_log.md) entries 13 and 16. No physical-device or high-refresh-rate rerun is claimed.
