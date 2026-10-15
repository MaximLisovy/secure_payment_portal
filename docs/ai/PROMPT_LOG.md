# AI Prompt Log

Key interactions with AI tools (Antigravity / Cursor / …) during this task.
The agent appends an entry after each significant task; the **Developer review**
part is written by me — that is where I show how I audited and refined the output.

---

## Template

### <NN>. <Short title> — <YYYY-MM-DD>
- **Tool / model:**
- **Goal:** what problem was being solved
- **Prompt (key part, verbatim):**
  > …
- **Context given:** rules / files / docs the agent relied on
- **AI output (summary):** what was produced, main design decisions
- **Assumptions & risks flagged by the agent:**
- **Developer review:** what I accepted, what I changed and why (sub-optimal parts, corrections)
- **Result:** files / commit

---

### 01. White-label foundation (Milestone 1) — 2026-10-15
- **Tool / model:** Claude Code, claude-sonnet-5-5
- **Goal:** Android flavors `retail`/`utility`, brand resolution from `appFlavor`, token `ThemeExtension`s with real `lerp`, one `ThemeFactory`, two brand configs and a token-only placeholder home, so adding brand #3 touches no feature code.
- **Prompt (key part, verbatim):**
  > Milestone 1 — foundation for the white-label engine. PLAN ONLY, no code yet. … Wait for my approval before writing code.
  >
  > Approved, with these decisions: A: move BrandConfig to lib/brands/brand_config.dart … D: an unknown flavor always throws; only a missing flavor falls back (non-release).
- **Context given:** `AGENTS.md`, `.agents/rules/multi-tenant-branding.md`, `review-checklist.md`, `testing.md`.
- **AI output (summary):** Plan first, then 7 steps. Four `ThemeExtension`s (`BrandColors/Shape/Density/Motion`) bundled in `BrandTokens`; `ThemeFactory.build(tokens, brightness:)` with an explicit `ColorScheme` and token-fed component themes; `BrandRegistry` is the only reader of `appFlavor`; `initialBrandProvider` → `activeBrandProvider` → `themeProvider`; a debug/profile brand switcher behind `!kReleaseMode`; a `brandOnSurface` role for brand-colored foregrounds. 80 tests; both flavor APKs built and run on an emulator.
- **Assumptions & risks flagged by the agent:**
  - The plan itself surfaced rule conflicts before any code: `BrandConfig` location (app↔brands cycle), `appFlavor` read in `main.dart` vs only in the registry, a redundant `themeData` field, `mocktail` not needed yet. All resolved in the rule files.
  - Environment: the only JDK was Temurin 25, which Kotlin Gradle plugin 2.2.20 cannot parse (`IllegalArgumentException: 25.0.1`); fixed with `flutter config --jdk-dir` pointing at JDK 21, documented in the README.
  - Found on a device screenshot, not by the tests, and fixed in this milestone: see the first correction below (Retail's vivid orange used as a foreground).
  - Rejected alternatives: `ColorScheme.fromSeed` (derives colors that are not tokens), a stored `themeData` on `BrandConfig` (two sources of truth), a `Map<Type, Object>` for feature configs (loses type safety), `ShapeBorder` fields in `BrandShape` (not always lerp-able).
- **Corrections made while building (AI suggestion → problem → correction):**
  - **One `primary` color for fills and foregrounds, checked by a contrast test of "on-color" pairs only** (primary/onPrimary, surface/onSurface…) → Material also uses `primary` as the foreground of text and outlined buttons, icons, the focus ring, the progress bar and the text cursor. Retail's vivid orange (#F57C00) is only 2.5–2.7:1 there (needs 4.5 for text, 3.0 for UI), and the test passed because it never looked at those pairs. Found by eyeballing an emulator screenshot → added a `brandOnSurface` role (Retail #C2410C, Utility reuses its navy), set every component foreground explicitly in `ComponentThemes`, and replaced the test with one table of 18 pairs (11 text at 4.5:1, 7 UI at 3:1) in `test/helpers/component_contrast_table.dart`. Each row reads its color from the built `ThemeData`, so a changed or unset component color is seen, not assumed. It runs for every registered brand, and a meta-test proves it flags the old Retail values.
    - Running the wider table on the old values found two more defects of the same class: the input border (`outline`) was 1.3:1 on Retail and 2.3:1 on Utility (now #94806A and #738299), and Utility's snackbar action (slate accent on a near-black bar) was 2.4:1, so the action now uses the text color.
  - The plan promised `.vscode/launch.json` (Q5 "include both") but the first pass never created it → noticed when re-reading the approved decisions; added debug and profile configs for both flavors.
  - Recalled `EquatableMixin` and `Override` from the main Riverpod barrel → equatable 3.0.0 has only `abstract mixin class Equatable`, and `Override` lives in `flutter_riverpod/misc.dart` → read the installed package source before writing code.
  - `LinearGradient.lerp(a, b, 0)` returns a gradient with explicit `stops`, so `lerp(0) == a` failed → `lerpGradient` returns the endpoint at t = 0 / 1.
  - Utility `controlHeight` was applied on top of `VisualDensity.compact` (-8dp), shrinking buttons twice → documented the order and set the value on purpose.
  - A test named "does not rebuild" passed even with `.select` removed (mutation check), because `ThemeData` equality already suppresses the emission → renamed it to what it really proves.
  - A theme test first asserted before `await container.pump()`, so it saw only the initial value → pump added.
- **Developer review:** _(to be written by the developer)_
- **Result:** Gradle flavors + manifest label; `lib/core/design_system/**`, `lib/brands/**`, `lib/app/**`; `test/**` (80 tests); `.vscode/launch.json`; README, AGENTS.md (use-case and git rules) and the multi-tenant rule file updated. Committed on `main`: one feature commit, then this log entry as the milestone-closing commit.

---

### 02. Milestone 1 follow-ups: accessible-by-default scheme, decorative outline, scaling notes — 2026-10-15
- **Tool / model:** Claude Code, claude-sonnet-5-5
- **Goal:** make unthemed Material widgets readable by default, give decorative borders their soft look back without weakening control borders, write down the later work without building it, and fix the git identity.
- **Prompt (key part, verbatim):**
  > map ColorScheme.primary to brandOnSurface (the accessible tone) and apply the vivid brandPrimary explicitly only where a fill is intended … Add a decorative outline role (mapped to ColorScheme.outlineVariant) for dividers and card borders. WCAG 1.4.11 exempts decorative borders, so leave it out of the 3:1 table and say so in a comment.
- **Context given:** `AGENTS.md`, `multi-tenant-branding.md`, the contrast table from entry 01.
- **AI output (summary):** `ColorScheme.primary` is now `brandOnSurface` and `onPrimary` reuses `surface`; fills stay explicit. New `outlineSubtle` role for card border, divider and progress track. Six more table rows for the `ColorScheme` defaults that unthemed widgets read, plus meta-tests (the old vivid Retail still fails; a soft outline used for a control fails). A "Scaling and later work" rule section and a scaling path in the insight report, both text only. Global git identity set and the existing commits re-authored. 83 tests; both flavor APKs built and checked on an emulator.
- **Assumptions & risks flagged by the agent:**
  - `onPrimary` reuses `surface` instead of a new token, because the table already requires `brandOnSurface` to hold 4.5:1 against every neutral surface and contrast is symmetric.
  - Observed on the device, not fixed: an unthemed Slider's inactive track is very faint on both brands (`surfaceContainerHighest` maps to `surfaceElevated`). The thumb and active track still carry the value. Fix when a feature needs a Slider: theme it explicitly with an inactive track from `outline` and add a table row.
  - The `ColorScheme` default is only a backstop for widgets nobody themed. Anything a feature actually uses should still be themed explicitly and get a table row.
- **Corrections made (AI suggestion → problem → correction):**
  - **Foregrounds patched one component at a time while `ColorScheme.primary` stayed the vivid fill** (my own fix in entry 01) → every widget nobody themed (Switch, Checkbox, Slider, focus, progress) still read the vivid color, so the trap stayed open for the next feature. The developer pointed it out → made the scheme the safe default (`primary` = accessible tone) and made the vivid fill the explicit, opt-in case; added table rows for the scheme defaults so that is enforced.
  - **One `outline` role for control borders and decorative borders** (entry 01 raised it to 3:1 for inputs) → Retail's card borders and dividers inherited the heavy tan and lost the soft look → split a decorative `outlineSubtle`, documented the WCAG 1.4.11 exemption in the table, and added a meta-test so the soft role cannot be used for a control without failing.
  - **Documentation drift:** adding `brandOnSurface` in entry 01 did not update the rule file's `BrandColors` row, which still listed the old roles → corrected together with this change, with a short "Color roles and contrast" rule.
- **Developer review:** _(to be written by the developer)_
- **Result:** commits `c0de752` (scheme), `5db62a4` (outlineSubtle), `21a2c0b` (docs), then this log entry. History re-authored to the configured identity.

---

### 03. Domain and fake data for payment and security (Milestone 2) — 2026-10-15
- **Tool / model:** Claude Code, claude-sonnet-5-5
- **Goal:** a pure-Dart domain for both features, fakes behind the interfaces the native side will implement later, DI, and tests, so that the payment flow (M3) and the native modules (M4, M5) can be built without touching domain or presentation.
- **Prompt (key part, verbatim):**
  > Milestone 2 — domain + fake data for payment and security. PLAN ONLY, no code yet. … Their interfaces must let the real channel-based sources drop in later unchanged. … Wait for my approval.
  >
  > Approved, with two changes: 1. Result/Failure: drop "Failure extends Result<Never>" and the FeatureFailure extension point. Use sealed Result<T> = Success<T>(value) | Err<T>(Failure failure) … 2. Interface segregation: split SecurityRepository into SecurityStatusRepository … and SecureWindowController.
- **Context given:** `AGENTS.md`, `testing.md`, `android-native.md`, `docs/platform_channels.md`.
- **AI output (summary):** Plan first, then four green steps. `core`: `Result`/`Err`, an abstract `Failure` with generic failures, typed data-layer exceptions and one `failureFromError`, `Money` (minor units, never a double), `ReplayLatest`, the wire contract constants and a validating `WireReader`. Security: tri-state `Detection`, a `RootAssessment` that is detected with signals, clear or unknown, `SecurityPolicy` (fail-closed for an unverifiable root), two small interfaces over one platform data source. Payment: bills whose total is derived from the lines, a sealed `PaymentProgress` that mirrors the native service state, and `ConfirmPayment` as the only use case. Data sources are split into a bill backend (a fake for good) and the processing the foreground service will replace. A contract suite defines what any implementation of each platform source must do. 326 tests; both flavor APKs build.
- **Assumptions & risks flagged by the agent:**
  - The processing was split from the bill backend because only the processing is replaced by native code; one source would have forced the channel implementation to fetch bills too. This departs from the request, which described one fake.
  - Fail-closed for an unverifiable root means iOS is blocked by design (documented in the README), and a rootable emulator image (userdebug, with `su`) could block payment on a grader's emulator once the native checks exist. Weak signals (test keys, debuggable) are allowed by default for that reason. To verify in the security-native milestone.
  - A recording that starts during processing does not cancel the payment (the developer's decision): the payment is already authorized and the window is secured.
  - The fakes are deterministic (fixed delays, counted transaction ids, injectable clock) but the real service will not be; the contract suite is what keeps them honest.
- **Corrections made (AI suggestion → problem → correction):**
  - **`Failure extends Result<Never>` plus a `non-sealed FeatureFailure` extension point** (the AI's plan) → relied on covariance, was hard to explain, and made switches exhaustive only at category level. The developer replaced it → `Err<T>(Failure)`, an abstract `Failure` in core and a `sealed` sub-hierarchy per feature, so a `switch` over a feature's failures is exhaustive.
  - **One `SecurityRepository` for status and window protection** (the AI's plan) → a screen that only protects the window would depend on status reading. The developer asked for interface segregation → `SecurityStatusRepository` and `SecureWindowController`, one platform data source behind both.
  - **`watchStatus` written as an `async*` generator** → cancelling an `async*` stream that is waiting on a quiet inner stream only takes effect at its next `yield`, so `cancel()` never completed and the native listener would have stayed registered until the next recording event. Found by a test that hung, not by review → rebuilt on a `StreamController` whose `onCancel` releases the inner subscription at once, and added a rule to `android-native.md`.
  - **`ConfirmPayment` (domain) importing the security barrel** that now exports the DI providers → pure-Dart domain pulled Riverpod and the data layer into its import graph → added `security_domain.dart`, a pure-Dart barrel that `security.dart` re-exports.
  - **Planned to use `fakeAsync` for time-based tests** → `flutter_test` does not export it, and `fake_async` is not in the approved stack table → used `testWidgets` with `tester.pump(duration)`. That exposed two fake-clock pitfalls that cost two hung test runs: awaiting a subscription `cancel()` inside `testWidgets` never completes, and a `Stream.multi` done event is not delivered under the fake clock. Documented in `test/helpers/fake_time.dart` and in `testing.md`, and added a per-file watchdog to find hangs quickly. **Update, see entry 04: these "pitfalls" were really a `ReplayLatest` bug** (a `Stream.multi`, then nested forwarding, loses the done event and never completes `cancel()` under a fake clock), not widget-test quirks. They were fixed at the root and the notes deleted.
  - **Contrived test helpers** (a copy-with extension on the entity, a `copyAmount` extension on a DTO) written instead of building the expected value directly → noticed while writing, removed, expected values are now plain constants.
- **Developer review:** _(to be written by the developer)_
- **Result:** commits `056a8ad` (core), `977790c` (security), `233b355` (payment), `5b20132` (channel contract draft and rules), then this log entry. Contract draft in `docs/platform_channels.md`.

---

### 04. Time-based tests move to fake_async — 2026-10-15
- **Tool / model:** Claude Code, claude-sonnet-5-5
- **Goal:** replace the widget-test workarounds around fake time with the proper fake clock, and delete the notes that explained them.
- **Prompt (key part, verbatim):**
  > fake_async: yes, add it as a dev dependency (it's already in pubspec.lock via flutter_test) and add it to the stack table. Move the pure-Dart time-based tests to fakeAsync, keep testWidgets for widget tests only, and remove the workarounds and pitfalls from testing.md that no longer apply. Commit separately.
- **Context given:** `AGENTS.md` (stack table), `testing.md`, the M2 test suite.
- **AI output (summary):** Three commits: the direct dev dependency and the stack table row; a rewrite of `ReplayLatest`; and the migration of the fakes, the platform contract suite and the default-wiring tests to `fakeAsync`, with `FutureProbe` and `expectNoPendingTimers` helpers. 329 tests.
- **Assumptions & risks flagged by the agent:**
  - `fakeAsync` cannot `await`, so tests start work with `unawaited(...)`, advance time, and read outcomes through a probe. Slightly less natural to read than a widget test, but it no longer needs a widget binding.
- **Corrections made (AI suggestion → problem → correction):**
  - **The M2 workaround.** When `flutter_test` did not export `fakeAsync`, I avoided the unapproved dependency, built on `testWidgets`, and documented two "pitfalls" plus a `settle` helper in `testing.md` → the developer approved the dependency when asked. I should have asked at the time instead of working around it for a milestone.
  - **Assuming the pitfalls would vanish with `fakeAsync`.** I expected `cancel()` and stream completion to behave under `fakeAsync`; a probe showed they did not, so they were never a `testWidgets` quirk → the cause was in `ReplayLatest`: a `Stream.multi`, and nested forwarding, lose the done event under a fake clock, and a `cancel()` whose `onCancel` returns nothing completes on the root zone, which a fake clock never runs. Rebuilt it from per-listener controllers with their own `onCancel` futures, and added a regression group. The pitfall notes could then be deleted instead of carried forward.
- **Developer review:** _(to be written by the developer)_
- **Result:** commits `414531e` (dependency), `2aaff65` (`ReplayLatest`), `3fedec3` (migration), then this log entry.

---
