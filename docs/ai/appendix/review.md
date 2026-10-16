# Appendix D: Final review against the checklist

Part of the [AI Insight Report](../AI_INSIGHT_REPORT.md). The checklist is [`.agents/rules/review-checklist.md`](../../../.agents/rules/review-checklist.md),
originally run at the end of an earlier milestone by the agent that wrote most of it. The initial checklist below is historical;
the [two-review findings](#two-review-findings-and-approved-fixes) supersede its outdated claims. A source regex is a guardrail,
not proof, and historical device results do not validate the later review fixes.

✅ checked, as it should be. ⚠️ a deviation that stays, and why. ❌ found and fixed in this pass.

## Architecture

- ✅ **Dependency rule guardrails.** Source regexes inspect imports and fake identifiers in `test/architecture/layering_test.dart`.
  They do not parse Dart or prove architecture. Domain remains pure; simulation-only controls now live in data and are exposed
  to debug tooling through DI/public barrels, as requested in the later review.
- ⚠️ **File size.** The current payment flow coordinator is 354 lines, above the 200–250-line smell guideline. Verdict timing
  and reconciliation timers are separate helpers; the notifier still owns flow transitions. This is an acknowledged maintenance
  cost, not a claim that every file is small. The original sizes were 226 and 195 lines for the notifier and native service.
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

- ✅ **Reply safety.** SafeResult submits at most one reply on main; it cannot guarantee that a handler replies. A cancelled
  call may receive none. Coroutine scopes are cancelled on destroy/detach, and blocking root probes are abandoned outside the
  waiting scope. Handler and concurrent-reply tests exercise these paths.
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
- ⚠️ **Measured on an emulator only.** On a phone the performance overlay showed 120 FPS with no visible drops, an observation; the harness (`M6-6`) was not run there, so no numbers are claimed for 90 or 120 Hz.

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

Everything that needs a person and a phone is in [Manual QA](../../MANUAL_QA.md). It was run once, on 2026-10-16, on a ZTE
RedMagic 10 Pro (Android 16), with a profile build from before the last three code commits. It settled the recording callback
under `FLAG_SECURE` (it did not fire, and the saved recording is black: `FLAG_SECURE` is verified against recording and the detection is defense in depth; an emulator experiment showed that the stock recorder does trigger it even with `FLAG_SECURE`, so the silence is more likely that maker's recorder, not proven) and saw the live progress
notification, Cancel and backgrounding during a payment work, with 120 FPS and no visible drops on the performance overlay. It
did not cover the notification permission prompt, the shade in detail, the lock screen, swiping the app away, API levels other
than 36, how fast Utility's 1.6 s scan feels, or frame-timing numbers (the harness was not run on the phone); each is marked
*not tested*. The wire contract is final. The CI workflow has run on GitHub and is green.

## Earlier Codex review and approved implementation

Codex reviewed the code, found defects and, with the developer's approval, implemented the earlier fixes (13 commits,
about 2,300 lines, including the attempt-id rewrite). The developer reviewed the plan and smaller diffs and verified the
large change through tests and device runs. Entries 09–21 in the [working log](working_log.md) record that pass.

## Two-review findings and approved fixes

Two subsequent independent reviews ranked payment correctness first. The developer consolidated their findings into the
13 items below and approved the batch 1 plan, adding active snapshot reconciliation, an explicit classification table and
named deadlines. The table records the supplied findings without inventing reviewer scores, quotes or separate reports
that were not supplied. Batches 2–4 continued under that authorization; verdict-hold logic was not changed.

| Item / finding | Implemented correction | Evidence and limits |
|---|---|---|
| 1. Transport failures looked like failed payments, enabling unsafe retries | Unknown start outcomes and unreadable/unscoped progress retain the attempt, stream and Cancel; immediate attempt-scoped native snapshots retry with capped backoff for 30 s; expiry shows guidance without payment retry | Repository classification table, source contract suites, JVM snapshot tests, late-terminal/cancel/replacement tests; both named surviving mutations are killed. In-memory snapshots are not durable backend history |
| 2. Silent EventChannel activation left startup waiting indefinitely | Named 5 s first-event deadline enters an unavailable blocked state; Check again opens a new subscription | Tests include actual missing-plugin activation via FlutterError, deadline boundaries, disposal, first error and late replay; README iOS claim corrected |
| 3. Invalid numeric fields and unexpected mapping exceptions escaped | WireReader validates numeric ranges and non-empty identities; repositories contain unexpected errors; both notifier subscriptions handle stream errors | completedAtMillis = 9223372036854775807 tested through parsing, stream mapping and snapshot recovery; invalid active events remain uncertain outcomes |
| 4. Sensitive content appeared before window confirmation | SecureScreen withholds its child until protected, uses a neutral placeholder while pending, and shows a blocked message/protection retry on failure | Delayed/failed protection and existing lifecycle/navigation widget tests; no new physical-device run |
| 5. Weak clean checks could yield a clean root verdict | Every probe declares strength; NOT_DETECTED requires a conclusive strong clean check when no signal fires; copy says “No root indicators found” | JVM aggregation cases; File.exists absent/inaccessible ambiguity and availability trade-off documented |
| 6. Structured cancellation could wait for blocking root probes | Detector-owned IO workers run outside the awaiting scope; waits time out without joining late calls; detector scope closes on detach | Real CountDownLatch-blocked IO-thread JVM test plus cancellation/concurrency cases; OS calls may outlive the wait |
| 7. Both tenants and demo catalogs shipped in each release | Const kReleaseMode/appFlavor filtering; brand-owned registrations/demo seeds; generic feature catalog injected through root DI | strings on all three AOT architectures per release APK and ASCII/UTF-16 scans of every decompressed entry; own-marker positive controls. Future assets/imports still need the same artifact check |
| 8. No in-app phone frame-timing numbers | Debug/profile SchedulerBinding collector with rolling 600-frame count, reported display Hz, p50/p90/p99/worst build/raster ms and Reset | Percentile/eviction/reset/publication/callback lifecycle tests; phone table and ADB-free QA steps. New phone numbers remain unmeasured; display Hz is not measured FPS |
| 9. Simulation controls/test hooks/permission data/promo/singleton inconsistencies | Controls moved to data and exposed through DI; test-only hooks annotated; permission reply is void; promo no longer asserts an arbitrary bill discount; singleton exception documented | Analysis, architecture guardrails, native permission result cases and full suites. Tenant fixtures/stale ownership comment were already resolved in item 7 |
| 10. Reply, architecture and recorder claims were too strong | At-most-one reply distinguished from liveness; regex checks described as guardrails; API 35 callback described as app recording visibility | Implementation and official Android API contract checked; active-recorder detection brief only partially met |
| 11. README setup/platform/release guidance was stale | Compact quickstart, registration-owned bill setup, API table, release install link/steps, truthful iOS and profile-demo guidance | Documentation link test and full validation; release link supplied by developer, no upload performed |
| 12. Codex's contribution and AI examples were inaccurate/noisy | Precise earlier-pass attribution and developer verification; shortened Insight sections; Prompt Log highlight 3 replaced with entry 25's refuted recording hypothesis | Historical decision preserved in working log, experiment caveats preserved, process noise removed |
| 13. Delivered APKs did not match final source | Dedicated final build packages both releases and both arm64 profile APKs with SHA256SUMS and source revision | Final artifact hashes/revision and validation are recorded in working-log item 13; artifacts remain outside git |

Validation for items 1–12: formatting, zero-issue analysis, all 887 current Dart tests, all 226 Kotlin JVM tests under JDK 21,
and both flavor debug builds. Release brand isolation was also checked on actual APKs. Each item has its own green
Conventional Commit; per-item details and any corrections are in [working log entries 26–29](working_log.md).

Remaining limits: no durable intent store, server idempotency or backend reconciliation; root heuristics are bypassable;
recording visibility is API/OEM dependent; the new fixes and frame-statistics readout have no physical-phone rerun. The older
phone and emulator results above are historical. The 354-line flow coordinator remains a maintenance deviation from the file-size
guideline. A large passing suite and source regexes are evidence for the exercised cases, never proof that all defects are gone.
