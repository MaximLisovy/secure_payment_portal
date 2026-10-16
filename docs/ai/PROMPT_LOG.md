# AI Prompt Log

Key interactions with AI tools during this task. The agent appends an entry after each significant task; the **Developer
review** part is where I show how I audited and refined the output.

Entries 01 to 08 and 22 were written by Claude Code (`claude-sonnet-5-5`). Entries 09 to 21 were written by a second agent
(OpenAI Codex), which I ran deliberately as an independent reviewer when the first agent's quota ran out: it found the
defects the first agent's tests had not, proposed the fixes, and I approved each plan after reviewing it. Every developer
review in this log is **DRAFT**: written by an agent from the decisions I gave during the work, with `[confirm]` where it
is unsure, for me to edit in my own words.

## Highlights

Three interactions that show how the work was steered. The full log follows as the appendix.

### 1. The plan gate changed the architecture before any code existed ([entry 03](#03-domain-and-fake-data-for-payment-and-security-milestone-2--2026-10-15))

The AI's plan for the domain layer made `Failure` extend `Result<Never>`, with a non-sealed extension point for features,
and put status reading and window protection behind one `SecurityRepository`. The developer rejected both before a line was
written: a sealed `Result<T>` (`Success` or `Err(Failure)`) with an abstract `Failure` in core and a sealed family per
feature, so that a `switch` over a feature's failures is exhaustive; and two small interfaces over one platform data
source, so the screen that only protects the window does not depend on reading status. Every later layer (the payment flow,
the native bridge, the tests) was built on those shapes. The same milestone shows the other half of the loop: the AI's own
`async*` stream, which cancelled only at its next event, was found by a test that hung, not by review.

### 2. The device overruled the AI's plan, its comments and the rule file ([entry 07](#07-payment-foreground-service-milestone-5--2026-10-16))

The plan, the KDoc and the Android rule file all said the same thing: post the final "Payment complete" notification, then
stop the foreground service. On the emulator, `dumpsys notification` showed the result was a notification that could not be
dismissed and lost its auto-cancel flag, because the system keeps the foreground notification non-cancellable until the
service detaches. The order was reversed (detach first, then post) and all three texts were corrected. In the same milestone
the developer changed the Cancel action from a service start to a non-exported broadcast receiver, so cancelling does not
depend on the service being alive, and changed the process: the agent runs every `adb` step itself, and what needs a person
goes into one checklist, run once on a phone at the end. A plausible-looking result ("instant success after swiping the app
away") turned out to be a slow `uiautomator` dump, and was proved so with fixed-coordinate taps and a notification-only probe.

### 3. A product rule from the developer, and an honest measurement ([entry 08](#08-the-security-scanning-animation-milestone-6--2026-10-16))

The developer observed that a real device check takes 0.1 to 0.5 s, so the scan would be a flash that nobody sees in a
release build, and changed the plan: the verdict waits for the sweep to complete a revolution, derived from the brand's own
period with no number to configure, with the period clamped to 1.6 to 3 s. The AI then measured the animation on an
emulator and the first raster numbers looked like a failure (about 40 % of frames over budget). Instead of reporting the
good half, it added two references to the harness, Material's spinner and a layer that draws one dot, which showed the same
numbers: that is the emulator's swap path, not the drawing. The report states the UI-thread cost, the allocation count and
the frame rate that carry over, says what does not, and leaves the phone run to the manual checklist.

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
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Approved the plan with four decisions: `BrandConfig` lives in `lib/brands/` so brands never import `app`; an unknown flavor always throws and only a missing one falls back, outside release; the brand switcher is behind `!kReleaseMode`; light theme only. `mocktail` and the brand assets and launcher icons were deferred (the icons landed in the final milestone). Accepted the `brandOnSurface` role and the table of component contrasts that the AI added after finding Retail's orange unreadable as a foreground on a device screenshot, and asked that the `.vscode/launch.json` promised in the plan be included.
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
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Pointed out that fixing one component at a time left `ColorScheme.primary` vivid, and asked for the safe default instead: `primary` mapped to the accessible `brandOnSurface`, the vivid `brandPrimary` applied explicitly only where a fill is meant. Asked for a separate decorative outline role, exempt from the 3:1 table with a comment saying why. The later work (a brands manifest, CI, launcher icons) was to be written down and not built until the final milestone, where it was delivered; JSON design tokens and a monorepo stay described in the appendix. Accepted the known weak spot: an unthemed Slider's inactive track is faint.
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
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Approved the plan with two changes: a sealed `Result<T>` (`Success` or `Err(Failure)`) with an abstract `Failure` in core and a sealed family per feature, instead of `Failure extends Result<Never>`; and `SecurityRepository` split into `SecurityStatusRepository` and `SecureWindowController`. Decided that a recording that starts during processing does not cancel a payment that is already authorised. Accepted splitting the bill backend from the processing source, which departed from the request because only the processing is replaced by native code. When asked, approved `fake_async` (entry 04): the AI should have asked instead of working around it.
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
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Approved `fake_async` as a dev dependency and its row in the stack table, and asked for the pure-Dart time-based tests to move to `fakeAsync` (`testWidgets` for widget tests only), for the workaround notes to be deleted from `testing.md`, and for the work in separate commits. The cause turned out to be `ReplayLatest`, not widget tests, and was fixed at the root.
- **Result:** commits `414531e` (dependency), `2aaff65` (`ReplayLatest`), `3fedec3` (migration), then this log entry.

---

### 05. Payment confirmation UI and simulated sources (Milestone 3) — 2026-10-15
- **Tool / model:** Claude Code, claude-sonnet-5-5
- **Goal:** the payment confirmation screen on top of the M2 fakes (review, processing, receipt, failure, cancel), sections that a brand declares as data and a registry draws, screen protection that fails closed, and a demo panel that keeps working once the real native sources exist.
- **Prompt (key part, verbatim):**
  > Q2: fail closed. If SecureScreen cannot enable the secure window, the flow goes to Blocked with a new recoverable reason (screen protection unavailable, "Check again"). Same principle as root-unverifiable: an unverifiable security control blocks payment.
  >
  > Q7: changed. The demo panel must keep working after M4/M5: in non-release builds, add a "Simulated" mode per controllable source (security, payment processing). Real native sources are the default; switching to Simulated swaps in the fake at runtime, and the UI shows a visible "SIMULATED" badge while any simulation is active.
  >
  > Demo panel wiring: no `is Fake…` downcasts. Fakes implement small control interfaces (e.g. SecurityScenarioControl, PaymentScenarioControl); di/ exposes them as nullable providers that are null when a real source is wired. The panel depends only on those.
- **Context given:** `AGENTS.md`, `multi-tenant-branding.md`, `android-native.md`, `testing.md`, `review-checklist.md`, `docs/platform_channels.md`.
- **AI output (summary):** Plan first (§10 order, seven questions), then eleven green commits. Screen: `PaymentConfirmationPage` inside `SecureScreen`; one lazy `CustomScrollView` of *sliver* sections drawn by an immutable `PaymentSectionRegistry` keyed by spec type; the pay action pinned below it; a phase switcher that uses the brand's motion tokens and reduced-motion; the percentage and bar are the only widgets that rebuild on a tick. Security: `windowProtection` joins `SecurityStatus`, and an unprotected window blocks payment (new recoverable reason). Simulation: per source a real slot (empty until M4/M5), a simulated slot and a `SourceMode`; the fakes implement `SecurityScenarioControl` / `PaymentScenarioControl` / `BillBackendControl`; a debug panel and an app-bar SIMULATED badge that shows in every build mode. 516 tests (from 329); both flavor debug APKs build.
- **Assumptions & risks flagged by the agent:**
  - **M2 domain change.** Q2 needs the window state in the status, so `windowProtection` was added to `SecurityStatus`, its DTO, the mapper and the wire contract (`docs/platform_channels.md`). It is a draft contract with no native side yet, so nothing shipped breaks, but M4 must implement the key.
  - **Every M3 build is fully simulated.** The real slots are empty until M4/M5, so even a release build runs on fakes; it says so with the badge, but it is not a real build.
  - **A possible race, not fixed.** The device check can read the status before `enable()` on the secure window has answered, which would show "screen protection unavailable" for a moment (recoverable, "Check again"). Today the 600 ms bill load hides it; with a slow real channel it could appear. A fix would make the flow wait for the window to settle before it starts the check.
  - Switching the payment source in the panel while a payment runs abandons that payment on the old source. Debug-only, not handled.
  - `restartPaymentFlow` is skipped if the panel is closed before the window protection has moved (it checks `context.mounted`); the next "Check again" recovers.
  - Money and dates are not locale-aware (no `intl`, the developer's call; README says so). Utility's success green is 4.4:1 on its canvas, so success and danger are only used as icons (3:1), never as text.
- **Corrections made (AI suggestion → problem → correction):**
  - **`SecureScreen` was planned with a `RouteObserver`** that protects while the route is current → between "route visible" and "observer fires" there is a frame with a visible, unprotected page, and a popped page lost protection during its own pop animation. Rebuilt so it protects from `initState` to `dispose`, with widget tests that record the protection state on every frame.
  - **The stale terminal replay.** `ReplayLatest` replays the last progress on listen, and terminal states are sticky, so a flow started after an earlier payment first saw an old "success" and would have shown it as the receipt of the new payment. The flow now decides on the first replayed progress: resume a running payment of this bill, show the receipt of this bill, otherwise start a fresh check. Found while writing the state-machine tests, not in the plan.
  - **A listener in `SecureWindowNotifier.build()`** to follow a source switch → Riverpod 3 pauses a provider's own `ref.listen` while nothing listens to that provider, and the notifier is only ever `read`, so it never fired. Found by the first test of the feature; replaced by an explicit design: the notifier remembers the controller that protected the window, `retry()` moves protection when the source changed, and release always goes to the controller that enabled.
  - **A doc comment that contradicted the code.** I wrote "a payment already running keeps its scenario" for the fake, then read the scenario at the end of the run. The test written from the comment failed → the scenario is captured at start.
  - **Tests that passed on the first run** (every widget test of the screen) were suspicious. Mutation checks: pay always enabled, "Check again" for every block, a fixed row height, an unknown section silently skipped, `ref.watch` of the whole flow in the processing view, the protection not moved on a source switch, a release to the wrong controller, a forbidden import in each layer. All are caught now. Two checks first "survived" because my `sed` pattern no longer matched after `dart format` had re-wrapped the line; I only noticed because the count of changed lines was zero. After that every scripted edit asserts that it applied. The same silent miss happened once in a Python replace in a test file.
  - **A progress view that flashed 0% / 100% while fading out** into the result (it read the live flow state) → the processing and result views keep the last state they were given, which also keeps the percentage where it ended.
  - **Labels for the panel in `core/strings`** needed feature enums, and `core` may not import features → the strings stay constants in `AppStrings`; the enum→label mapping sits in the panel. An architecture test (new, unplanned) now holds the import rules, tenancy, domain purity and the "no fake in `app/`" rule, because until now only review enforced them.
  - A widget test harness added `instantBackend()` twice (once itself, once from a caller) → Riverpod refuses a duplicate override; the helper now takes the payment script as a parameter.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Decided that screen protection fails closed: if the secure window cannot be enabled the flow goes to a recoverable `Blocked` with a "Check again" action, the same principle as an unverifiable root. Changed the demo plan: a *Simulated* mode per controllable source, real sources the default, a visible SIMULATED badge while anything is simulated, and no `is Fake…` downcasts, only small control interfaces that the fakes implement and `di/` exposes as nullable providers. Accepted money and dates not being locale-aware (no `intl`) and said so in the README. Before the native milestone asked for two fixes, each its own commit with tests: the device check must not read window protection until the window has answered, and the source switch is locked during a payment.
- **Result:** commits `0e0bab7` (formatters), `3dca855` (window protection in the policy), `5f6b16c` (SecureScreen), `a1b1316` (brand payment config), `8ae4a54` (flow state machine), `45bbd82` (the screen), `0a06d11` (control interfaces), `2431a90` (source modes), `29d7cb5` (demo panel and badge), `b6f1db3`, `c8adfb9` (docs), then this log entry. Before this milestone's final gate: format clean, analyze no issues, 516 tests pass, `flutter build apk --debug --flavor retail` and `--flavor utility` both built.

---

### 06. Security native module (Milestone 4) — 2026-10-15
- **Tool / model:** Claude Code, claude-sonnet-5-5
- **Goal:** the Kotlin side of device security (root detection, screen recording detection, `FLAG_SECURE`), the Dart channel source that passes the existing contract suites, and the Real slot wired, with the device facts checked on a Pixel_9 emulator instead of assumed. Two small fixes (a race in the screen-protection check, and a source switch during a payment) went first.
- **Prompt (key part, verbatim):**
  > Build SharedEventStream on top of the existing ReplayLatest instead of adding a third stream primitive, unless there is a concrete reason. If there is one, explain it.
  >
  > Whatever step 3 shows about the recording callback under FLAG_SECURE, keep the detection and record the finding honestly in docs/platform_channels.md and PROMPT_LOG: "defense in depth" if it never fires, "verified" if it does.
  >
  > Simulated mode: change it now. The secure window stays real in every mode; simulation replaces only the security status readings (root, recording, scenarios), never FLAG_SECURE. Wire SecureWindowController to the real channel source always.
- **Context given:** `AGENTS.md`, `android-native.md`, `docs/platform_channels.md`, the contract suites from M2, and an emulator I could boot and read with `adb`.
- **AI output (summary):** Plan first (files, threading per call, lifecycle table, API matrix, risks, eleven questions), then ten green commits. Kotlin: `Channels.kt` mirrored object for object (a Dart test fails on any drift), `SafeResult` (reply once, on main), six root checks behind small ports, `RootDetector` (concurrent, `unknown` only if every check is inconclusive), a reference-counted `SecureWindowController` whose count outlives the window, `ScreenRecordingMonitor` joining the Dart listener and the Activity lifecycle, and a thin `SecurityPlugin`. Dart: `ChannelSecurityPlatformDataSource` with call timeouts and one shared native listener, `ReplayLatest` extended for it, the Real slot wired, and a read-only "Device reports" block in the demo panel. 601 Dart tests, 101 JVM tests, both flavors and a release build compile. On the emulator: no root signals, a black screenshot and recents thumbnail under `FLAG_SECURE`, protection kept across rotation and Activity re-creation.
- **Assumptions & risks flagged by the agent:**
  - **The recording callback under `FLAG_SECURE` is unverified: pending manual verification.** Whether `addScreenRecordingCallback` reports the app as visible while its window is secure is not known. It needs the Screen record quick-settings tile, which the developer will run. `adb shell screenrecord` was tried and is not detected (it is not a MediaProjection capture), which says nothing about the tile. The detection stays either way, and the finding ("verified" or "defense in depth") is written into `platform_channels.md` and here when it is known, in a small docs commit. The security half of the contract stays **draft** until then.
  - Below API 35 the recording state is always `unknown`, and no emulator below API 36 was available, so that path is covered by JVM tests only.
  - Other emulator images were not available. From memory, not verified: a `google_apis` userdebug image has `test-keys` and often a `su`, which blocks by design.
  - The Real security source is now the default everywhere, so iOS, desktop and plain `flutter test` read the device as unverifiable and refuse payment, by design; the debug panel's Simulated mode gets a working screen there.
  - A consequence of keeping the window real in every mode: a screen recording of the payment page is black on every Android build, simulated or not, so a demo video of that screen needs another way to be captured.
  - Heuristic root checks are bypassable (Magisk DenyList, renamed packages); Play Integrity is out of scope.
- **Corrections made (AI suggestion → problem → correction):**
  - **The plan said a source swap keeps the window black both ways** → on the device, switching to Simulated left `FLAG_SECURE` off and the screen capturable: the simulated source had no Android window, so "moving protection to it" released the real flag. I had built exactly that move in M3. The developer decided the window is real in every mode → the simulation only scripts readings, a "screen protection available" scenario reports the failure without touching the flag, and the move-on-switch machinery (and its tests) was deleted as dead code.
  - **`getprop ro.debuggable` / `ro.secure` for the debuggable check** (in the plan, from the rule file) → from the app's SELinux domain both print nothing, so the check could never run and was always inconclusive, and no test could have shown it. Found on the device (with `run-as`, a close but not identical domain) → the check reads `Build.TYPE`, and the debug log now lists inconclusive checks so a check that silently cannot run is visible. Confirmed in the real process: `inconclusive=[]`.
  - **`Process.waitFor(timeout)` and `destroyForcibly`** came to mind for the command runner → both are API 26 and minSdk is 24. Checked in the SDK's `api-versions.xml` before writing: it polls `exitValue()` and calls `destroy()`.
  - **`RootDetector` rethrew every `CancellationException`** → a check that uses its own `withTimeout` would have cancelled the whole detection instead of being one failed check. Found while writing the tests; it now rethrows only if the caller itself was cancelled.
  - **A new `SharedEventStream` file** (the plan) → the developer asked for `ReplayLatest` unless there was a concrete reason. There was: it always replays its initial value (a made-up `unknown` that breaks the contract's first event) and has no first-listener or last-cancel hook to open and close the native subscription. It was extended instead of duplicated. A third need appeared while reasoning about reopening: a listener must never be replayed a value from before the subscription closed (a stale "not recording" would flicker the page to Ready during a recording), hence `forgetOnLastCancel`.
  - **My claim that the Android `EventChannel` keeps one active sink** was from memory → read in the embedding's bytecode before building on it: `onListen` swaps the sink and calls `onCancel(null)` on the old one, and `onCancel` cancels whichever is active.
  - **I assumed a failed `listen` (no native side) would error the stream** → Flutter's `EventChannel` swallows it and reports through `FlutterError`, so the stream is silent. Found by a test that hung; the behaviour is now pinned and documented.
  - **Waiting on the window state for the screen-protection race** (fix 1) → Riverpod forbids changing a provider in `initState`, where the request starts, so a synchronous `Pending` throws, and waiting on a state written a microtask later still races when the flow starts first. The request goes out at once, `Pending` is written a microtask later, and the flow waits on a future that is set synchronously. A mutation that wrote `Pending` synchronously failed every `SecureScreen` test, which is how the rule was confirmed.
  - **A Riverpod error in the new "Device reports" block** ("markNeedsBuild during build") when security was switched back to Real → the block's provider was created while its dependency chain was stale from the switch, and the rebuild invalidated it mid-build. Reproduced in a minimal widget, fixed by keeping the repository watched in the panel.
  - **Tests I wrote wrongly**: a concurrent-reply test appended to a thread-unsafe list (flaky, caught only when the whole suite ran again), three channel tests with timing mistakes, a contract-sync parser that first missed the template and camelCase mapping, and an assertion `+ 0.also { }` that meant nothing. One mutation (the default simulation is built with a scripted window) survived until a test was added for it. Scripted edits now assert they applied: one patch missed after `dart format` re-wrapped a test and failed loudly instead of silently.
  - **Dependency versions** from memory would have been wrong: `core-ktx` 1.19 needs `compileSdk` 37 and AGP 9.1. Read the AAR metadata and pinned 1.18.0.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Answered the eleven questions: below API 35 the recording state is always `unknown` with no heuristic; root is `unknown` only when every check is inconclusive; add a read-only "Device reports" block in Real mode; skip `setRecentsScreenshotEnabled`; timeouts are fine; add `./gradlew testDebugUnitTest` to the definition of done and the README; pin versions that resolve and report them; the security half of the contract stays draft until the device check; add the `Channels.kt` sync test; no extra emulator image. Asked for the shared stream to be built on `ReplayLatest` unless there was a concrete reason, and for the recording finding to be recorded honestly ("verified" or "defense in depth"). Decided that the secure window is real in every mode: simulation replaces readings only, never `FLAG_SECURE`. Chose to run the Screen record check later, on a phone, and not to block on it.
- **Result:** commits `bfb6690` and `6f08381` (the two fixes), `3655293` (Gradle and manifest), `27bfbb8` (`Channels.kt`, `SafeResult`, sync test), `2c9bc1c` (root detection), `e8f161d` (secure window controller), `f57b035` (recording monitor), `3ad0819` (`SecurityPlugin`), `deb68f7` (`ReplayLatest`), `38ec2f9` (channel data source), `3d0f7f2` (Real slot and Device reports), `e56b2da` (`Build.TYPE`), `dbc4594` (docs), `584a4e9` (window real in every mode), then this entry. The security half of the contract is draft; the recording finding is pending manual verification.

---

### 07. Payment foreground service (Milestone 5) — 2026-10-16
- **Tool / model:** Claude Code, claude-sonnet-5-5
- **Goal:** the Kotlin side of payment processing (a foreground service with a progress notification that simulates the payment), the Dart channel source that passes the existing payment contract suites, the Real slot wired, and every device fact checked on a Pixel_9 emulator with `adb` instead of assumed. What needs a person went into `docs/MANUAL_QA.md`.
- **Prompt (key part, verbatim):**
  > Handle the notification Cancel action with a non-exported BroadcastReceiver (PendingIntent.getBroadcast, FLAG_IMMUTABLE) that calls store.cancelIfRunning(), instead of PendingIntent.getService. Cancel then doesn't depend on the service being alive and avoids any service-start restrictions. Keep the manifest guard in sync.
  >
  > Process change (Q11): don't stop for manual checks anymore. Run every adb step you can yourself on the emulator. Collect everything that needs a human into docs/MANUAL_QA.md: one checklist grouped by milestone, each item with exact steps and the expected result.
- **Context given:** `AGENTS.md`, `android-native.md` §4.4, the payment half of `docs/platform_channels.md`, the payment contract suite from M2, the M4 security module as the pattern, and an emulator I could boot and read with `adb`.
- **AI output (summary):** Plan first (files, threading, lifecycle, API matrix, risks, ten questions), then thirteen green commits. Kotlin: a process-wide `PaymentProgressStore` (`StateFlow`, atomic transitions, one payment at a time, first of cancel and finish wins, a refused start gives its claim back), `PaymentProcessingService` as a `shortService` foreground service, `PaymentSession` with a `SimulatedPaymentProcessor` (20 steps of 400 ms, always succeeds), a throttled `NotificationUpdater` (two updates a second, the last value always posted), a generic private notification with a Cancel action sent to a non-exported receiver, `PaymentStarter` (claim, then start, mapping `ForegroundServiceStartNotAllowedException`), an explicit `requestNotificationPermission` bridge method, thin `PaymentMethodHandler` and `PaymentStreamHandler`, and a manifest guard test. Dart: `ChannelPaymentPlatformDataSource` (permission first and never blocking, call timeouts, one shared native listener) passing the contract suite unchanged against a Dart stand-in for the native side, `ReplayLatest.addError`, a typed "Open the app to pay" failure, and the Real slot wired, so a default build runs real payments and shows no SIMULATED badge. 636 Dart tests and 207 JVM tests pass; both flavors compile; a release (R8) build pays correctly.
- **Assumptions & risks flagged by the agent:**
  - **Pending manual verification:** the permission prompt, the shade and the lock screen as a person sees them, the notification on a physical phone's skin, other API levels, battery saver. They are `M5-1` to `M5-12` in `docs/MANUAL_QA.md`. The payment half of the channel contract stays **draft** until they are run.
  - **JVM only, not reproducible by hand:** `ForegroundServiceStartNotAllowedException` (it needs a start from the background), the 3 minute `onTimeout`, and the "Payment failed" notification, because the native simulation always succeeds. Declines and failures are Simulated scenarios.
  - **Below API 34 the type is masked to nothing by `ServiceCompat`**; that comes from reading its bytecode and was not run on an older device. No emulator below API 36 was available.
  - **A killed process loses an in-flight payment.** The state is in memory and the service is not sticky, by design. Documented, not persisted; the idempotency key and reconciliation that a real backend would need are described in section 6 of the AI Insight Report.
  - The 3 minute limit of `shortService` is fine for an 8 second simulation and would not be for a real backend call.
- **Corrections made (AI suggestion → problem → correction):**
  - **The final notification was posted before the service detached** (my plan, the KDoc and the rule file all said "post, then stop") → on the device the "Payment complete" notification had no `AUTO_CANCEL`: while it is still the foreground notification the system keeps it non-cancellable. Found by reading `dumpsys notification`, not by any test. Now detach first, then post; the KDoc and the rule say so.
  - **The manifest guard test went stale** → Gradle marked the test task up to date after the manifest changed, so a mutation that broke the manifest still passed. The manifest is now declared as a test input, and the mutation was run again and fails as it should.
  - **A test that did not test its name** (`progressOnlyGoesUp`) → it passed even when progress could decrease, because it asserted after a later, higher report. Found by the mutation check; it now asserts immediately after the lower report.
  - **A store method that failed "whatever is running"** (`failIfRunning`), used by the service when it died → between one service stopping and the next starting a new payment can already be claimed, and it would have been failed by the old service. The service now fails only the payment it ran, and the method was deleted as dead code.
  - **Cancel through `PendingIntent.getService`** (the plan) → the developer's change: a broadcast to a non-exported receiver, so Cancel does not depend on the service being alive and is not a service start. The manifest guard follows.
  - **`shortService` plus a `dataSync` fallback** (from memory) → the Javadoc says the system ignores `shortService` when it is combined with another type, so there is no fallback to add; declared alone.
  - **`ServiceCompat.startForeground` guarded by our own `SDK_INT` branch** (from memory) → it already passes the type on API 34+ and masks it to `0xFF` on 29 to 33. Read from its bytecode before writing the code, so the branch was never written.
  - **"The payment succeeds at once after the app is swiped away"** (my first reading of the device) → a measurement artifact: `uiautomator dump` takes about ten seconds while the screen never idles, so by the time I looked the payment had finished. Proved with fixed-coordinate taps and notification-only sampling: the service really keeps running (55% to 75% with no app).
  - **A contract-suite test that created the Dart stand-in at declaration time** → `addTearDown` may only be called inside a test; the suite now uses a constant duration.
  - **Mutations that did not count:** one (`Stopped → store.fail`) was an equivalent mutant because the store itself refuses the transition, and one did not compile under null safety. Neither proves anything; both are noted here so that a green mutation list is not read as stronger than it is.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Answered the questions: `shortService` alone; an explicit `requestNotificationPermission` before `startPayment`; leave "Payment complete" or "Payment failed" and remove it only on cancel; generic text only, private on the lock screen; native processing of 20 steps of 400 ms that always succeeds (declines stay in Simulated); the process-death limit documented, with the idempotency-key and reconciliation note in the insight report; a typed failure "Open the app to pay"; `addError` for the stream; a manifest guard test; no extra emulator, the physical phone covers another API level at the end. Changed the plan: the notification's Cancel is a non-exported `BroadcastReceiver` (`PendingIntent.getBroadcast`, immutable) calling `store.cancelIfRunning()`. Changed the process: the agent runs every `adb` step, and everything that needs a person goes into `docs/MANUAL_QA.md`, run once on a phone with a profile build at the end. Decided that the agent never pushes.
- **Result:** commits `7a9ae18` (manual QA checklist), `62fbe9d` (resources and permissions), `22748ec` (manifest as a test input), `dd4416a` (`requestNotificationPermission` in the contract), `f8179e0` (store), `933db0a` (processor and session), `2236579` (notification, throttle, cancel receiver), `ad40868` (start logic and handlers), `d0505a3` (service, plugin, manifest), `ece9233` (channel payment source), `49f6a2e` (Real slot), `52cb030` (detach, then notify), `6276f74` (drop `failIfRunning`), then this entry. Device checks on the emulator all passed (service type `0x800`, notification record, live progress, permission allowed and denied, cancel from the shade and the app, background, swipe-away, force-stop, release build). The payment half of the contract is draft, pending manual verification.

### 08. The Security Scanning animation (Milestone 6) — 2026-10-16
- **Tool / model:** Claude Code, claude-sonnet-5-5
- **Goal:** replace the spinner in the security card with a `CustomPainter` radar (a sweep and three staggered pulses) that is styled from the brand tokens only, repaints one layer, rebuilds nothing, allocates nothing per frame, and is measured on a device per brand.
- **Prompt (key part, verbatim):**
  > Q3 changed: the verdict waits until the sweep completes at least one full revolution — max(actual check time, one period), aligned to the end of the current revolution. No arbitrary config number: the dwell is derived from the brand's period. Rationale: the real check takes 0.1–0.5 s, and graders running a release APK (no demo panel) would otherwise never see the animation.
  >
  > Q5 adjusted: keep the period derived (slow × 4), but clamp it to [1.6 s, 3 s]. 0.96 s for Utility will likely look frantic. Confirm in the rendered PNGs and adjust the clamp if needed.
  >
  > Spike profile mode on the emulator first, as you proposed.
- **Context given:** `AGENTS.md`, `performance-custom-painter.md`, the M5 plan and PROMPT_LOG for style, the existing rebuild-count test, the brand tokens, and an emulator I could boot and drive with `flutter drive`.
- **AI output (summary):** A plan first (files, the maths with formulas and periods, a layer diagram, how zero rebuilds and isolated repaints are proved, risks, eight questions), then nine green commits. `ScanMath` (pure functions of the phase, with the seam argument written next to them), `ScanStyle.from(colors, motion)`, two painters in two repaint layers, `ScanAnimation` owning the one ticker with reduced motion parked on a still pose, the indicator switching scan and verdict in one box, the verdict held until a revolution ends (in the flow notifier, from the brand's period, off for reduced motion), a demo knob for how long the device takes and a performance overlay switch, an `integration_test` harness with a driver that writes a summary, and the docs. 754 Dart tests (up from 636); the Kotlin side is unchanged (207 JVM tests still pass); both flavors build; the release APK has no trace of `integration_test`.
- **Assumptions & risks flagged by the agent:**
  - **How fast the scan feels is unverified.** A still image cannot show speed: the rendered PNGs show the look (they led to two visual fixes) but not whether Utility's 1.6 s turn is frantic. The clamp stays at 1.6 s to 3 s. Pending manual verification (`M6-2`).
  - **The emulator's raster time says nothing about the scan.** Every variant, including a layer that draws one dot, rasterises in 13 to 16 ms there. Only the UI-thread time, the allocation count and the delivered frame rate carry over. Nothing is claimed for 90 or 120 Hz or a real GPU; the phone run is `M6-6`.
  - **The dwell is a product cost, chosen by the developer:** Pay is enabled 1.6 s (Utility) or 2.4 s (Retail) after the check starts, on every visit, even when the device answered in 100 ms. It is documented in the README and in section 4 of the AI Insight Report.
  - **Reduced motion has no dwell.** The developer's rule did not say; with nothing sweeping, waiting adds nothing. A decision of mine, flagged here.
  - The flow's timer and the animation's ticker start within a frame of each other, not at the same instant; the sweep keeps turning through the fade, so the revolution still completes on screen.
- **Corrections made (AI suggestion → problem → correction):**
  - **`debugOnProfilePaint` to count repaints** (my plan) → read in the SDK: it is called when a *parent* paints a child, so it never sees a repaint boundary repainting on its own, which is exactly the scan's case. The tests use `RenderRepaintBoundary`'s own counters instead; and my first guess of what "symmetric" means was backwards (it is the wasteful case, parent and child painted together), found by reading the doc before writing the assertions.
  - **`flutter drive --profile` as written in the plan** → the spike failed with a refused connection to the VM service: the test reads the VM service itself, which needs `--no-dds`. The error message said so. The spike existed to find this.
  - **The sweep shader "cached per size"** (my plan) → the gradient is angular and lives in the rotating frame, so it does not depend on the size at all. It is built once per painter, the geometry once per size, and the tests say so.
  - **The first render** had pulses too faint to see and rings and ticks that outweighed the animation → pulse alpha 0.55 to 0.8, ring stroke 0.75 to 0.5, a smaller centre dot, checked again on a new render.
  - **A test that compared `Paint` identity** → `TestRecordingCanvas` records copies, so identity can never match; replaced by "every colour drawn is from the prepared palette", compared as 8-bit channels because a `Paint` quantises its colour. Another test claimed the scan is never dimmer than 0.4; it is 0.397.
  - **A verdict held in the widget** (my first thought for the new dwell rule) → Pay and the card would disagree, since Pay reads the flow. The hold is in the notifier, as a periodic timer, with no wall clock, so the tests use fake time.
  - **The dwell inside `rootOverrides`** → every test that uses `pumpApp` would get it, and a test cannot override the same provider twice. It is its own list, added in `main()`, with a test that reads `main.dart` so a build cannot forget it.
  - **Mutation checks left five survivors:** `frac` for negative numbers, a painter rebuilt when only the reduced-motion setting changed, a dwell timer left running after leaving the page, a box size read from the very constant being tested, and one that changes a condition that cannot be true where it sits (equivalent, left alone). Each of the first four got a test.
  - **Raster 15 to 16 ms in "over budget in 40% of frames"** in the first measurement looked like a failure of the scan and was true of the stock spinner too → a fourth variant, a layer drawing one dot, was added to the harness as a floor. It showed the same, so the numbers are reported with that reading and not without it.
  - **Riverpod's refresh timer** left a pending timer in `testWidgets` after a provider changed → `pumpAndSettle` at the end of those tests.
  - **`flutter pub get` changed `ios/Flutter/*.xcconfig` and created `ios/Podfile`** when the plugin was added → reverted before every commit, never committed (the rule: do not touch `ios/`).
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Approved the plan: a mark one and a half control heights tall, radar only, reduced motion as a still pose, the demo knob for how long the check takes and a performance overlay switch (their own commit), and `integration_test` (added to the stack table). Changed the plan twice: the verdict waits for the sweep to complete a revolution, `max(actual check time, one period)` aligned to the end of the current revolution, derived from the brand's period with no number to configure, because a real check takes 0.1 to 0.5 s and a release build would otherwise never show the animation; and the period stays derived (slow × 4) but clamped to 1.6 to 3 s, because 0.96 s would probably look frantic. Asked for the profile-mode spike first, and that the phone-side checks go into `docs/MANUAL_QA.md`. Open: whether 1.6 s feels right is not decided from still images and is item `M6-2` for the phone.
- **Result:** commits `7978a72` (rebuild tracker helper), `0fd2c28` (maths and style), `0624a5c` (painters), `46ed8a9` (`ScanAnimation`), `4aba800` (the security card), `8938a25` (the verdict dwell), `8f4c2d3` (demo duration and performance overlay), `b63b703` (frame timing harness), `156bae4` (docs), then this entry. Emulator, profile mode, median of three 8 s runs: the scan costs 1.07 to 1.18 ms of UI thread per frame (floor 0.92 to 1.08, stock spinner 1.40), two garbage collections in 8 s (the floor two, the spinner six), 59 to 60 frames per second on a 60 Hz display. The phone checks are `M6-1` to `M6-11` in `docs/MANUAL_QA.md`.

---

### 09. Restore the documentation validation baseline — 2026-10-16
- **Tool / model:** OpenAI Codex, GPT-6
- **Goal:** fix the missing demo-script target found during independent review before changing payment contracts.
- **Prompt (key part, verbatim):**
  > давай тогда поправь то что нашел
  > да, погнали
- **Context given:** the approved review-fix plan, AGENTS.md, testing.md, the existing README and manual QA checklist.
- **AI output (summary):** added docs/DEMO_SCRIPT.md with the recording setup, brand/native/simulated scenarios, and honest device-performance limits. Preserved the developer's uncommitted README and appendix drafts.
- **Assumptions & risks flagged by the agent:** the script is a recording plan, not evidence that manual QA has been performed.
- **Corrections made (AI suggestion → problem → correction):** README linked a demo script that did not exist, making the documentation test fail → added the actual script instead of weakening the test.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** I ran Codex on purpose as an independent reviewer when the first agent's quota ran out, and its first act was to read the repository and report what it found. This is the first finding: the demo script that the documents pointed to did not exist. I approved the complete review-fix plan before it changed anything. [confirm: when and how much of the plan you read]
- **Result:** 825 Dart tests pass; flutter analyze has zero issues; Dart formatting passes. Commit: docs: add the missing demo recording script.

---

### 10. Serialize secure-window ownership — 2026-10-16
- **Tool / model:** OpenAI Codex, GPT-6
- **Goal:** balance native acquisitions across overlapping acquire, release and retry calls.
- **Prompt (key part, verbatim):**
  > да, погнали
- **Context given:** approved review-fix plan; the secure-window notifier, controller contract and regression probes.
- **AI output (summary):** one reconciliation owns the in-flight platform command, retries share it, and holder changes are applied before the final state is published. A failed disable retains the native claim for a later holder instead of stacking another enable.
- **Assumptions & risks flagged by the agent:** a platform timeout still cannot prove whether the native operation happened; the existing typed failure remains visible. No Android API changed.
- **Corrections made (AI suggestion → problem → correction):** tracking the pending future without sharing it allowed duplicate enable calls → share the reconciliation and test overlapping retry, replacement during enable, replacement during disable and failed disable/reacquire.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Part of the review-fix plan I approved: acquire, release and retry of the secure window are serialised, so overlapping calls balance. [confirm: you read the diff and the new notifier tests]
- **Result:** format and analyze pass; all 831 Dart tests pass (includes the following immutable-entity step). Commit: fix: serialize secure window ownership changes.

---

### 11. Make entity collections immutable snapshots — 2026-10-16
- **Tool / model:** OpenAI Codex, GPT-6
- **Goal:** prevent external collection mutation from changing a bill total or a root assessment.
- **Prompt (key part, verbatim):**
  > да, погнали
- **Context given:** approved fix plan; domain entities, their mappers and fixtures.
- **AI output (summary):** PaymentDetails copies lines into an unmodifiable list; RootDetected copies signals into an unmodifiable set. Updated only the affected const construction and fixtures, and tested both input aliasing and mutation through the entity.
- **Assumptions & risks flagged by the agent:** these two constructors can no longer be const because copying collections executes at construction time. This exception to the const preference was explicitly included in the approved plan.
- **Corrections made (AI suggestion → problem → correction):** final collection references were described as immutable entities → their contents and aliases remained writable → own immutable copies and verify the original collection can be cleared without changing the entity.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Part of the same plan: the bill's and the root assessment's collections become immutable snapshots, so a caller cannot change a total or a signal list after the fact. [confirm: you read the diff]
- **Result:** format and analyze pass; all 831 Dart tests pass. Commit: fix: protect domain entities from collection mutation.

---

### 12. Reconcile replacement holders after an enable failure — 2026-10-16
- **Tool / model:** OpenAI Codex, GPT-6
- **Goal:** cover a replacement screen arriving while a no-op release reconciliation is completing.
- **Prompt (key part, verbatim):**
  > да, погнали
- **Context given:** the approved fix plan, secure-window ownership tests and follow-up self-review.
- **AI output (summary):** reconciliation checks desired ownership again after its deferred no-op state update, and continues to enable if a new holder arrived. Added a failed-enable → overlapping release/acquire regression.
- **Assumptions & risks flagged by the agent:** failed native operations still report typed failure; no newer Android API was introduced.
- **Corrections made (AI suggestion → problem → correction):** the first serialized reconciliation could return after a holder changed during its no-op await → continue reconciliation until the current desired ownership is applied.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** A follow-up found by the same review: a replacement screen arriving while a no-op release was being reconciled. Covered by the plan I approved.
- **Result:** formatting, zero-issue analysis, all 844 Dart tests and both debug APKs pass. Commit: fix: reconcile replacement holders after protection failure.

---

### 13. Isolate payment attempts across Flutter and Android — 2026-10-16
- **Tool / model:** OpenAI Codex, GPT-6
- **Goal:** fix stale payment results, lost service work, obsolete confirmation, stale security snapshots and invisible cancellation errors found in independent review.
- **Prompt (key part, verbatim):**
  > давай тогда поправь то что нашел
  > да, погнали
- **Context given:** the approved file-by-file fix plan, AGENTS.md, native/testing/review rules, existing contract suites and the review reproductions.
- **AI output (summary):** schema v2 carries a fresh attemptId separately from the bill ID in start/cancel and all non-idle progress. The store scopes progress, completion, rollback and cancellation to the attempt. Notification PendingIntent data makes old actions distinct. PaymentWorkerCoordinator cancels and joins retired work, tracks every delivered service startId, and lets only the current worker stop foreground processing. ConfirmPayment prepares permission first, reads security afterwards and checks obsolete confirmation after awaits. Flutter filters events, preserves acceptance rejection and shows cancellation failure while progress continues. Updated fakes, simulator, contracts, widgets and regressions together.
- **Assumptions & risks flagged by the agent:**
  - The schema change is coordinated inside one app; v1 consumers must not mix with v2. Attempt IDs are local execution identities, not durable backend idempotency keys; process-death recovery remains out of scope.
  - Physical-device callback, notification and high-refresh-rate checks remain pending. The only newly used Android API is Intent data/Uri parsing (API 1); other guarded APIs are unchanged.
  - A release build with --no-pub failed on an existing stale GeneratedPluginRegistrant reference to the dev-only integration_test plugin. A retry of the normal Flutter build command, letting Flutter regenerate its own files, was rejected by automatic approval review because of the repository's generated-file restriction. No generated file was edited manually and no release success is claimed for v2. Debug builds and required checks pass.
  - An initial approval review also rejected updating the native rule description. The approved plan explicitly listed that file; after presenting this evidence, the narrow documentation synchronization was approved. No safety rule was weakened.
- **Corrections made (AI suggestion → problem → correction):**
  - Atomic transitions keyed by a bill allowed old work to finish a retry → carry a distinct attemptId and test old progress/success/failure/rollback/cancel after replacement.
  - Ignoring every start while a Job was active lost accepted replacement work → distinguish duplicates, join retired workers and guard cleanup. An obsolete Intent still advances Android's stop startId, so every delivery is tracked.
  - Permission requested after security verification preserved a stale verdict → prepare first, then perform the final domain check, with a channel-backed 40-second-prompt regression.
  - Ref.mounted alone did not invalidate a changed bill → generation guards prevent obsolete preparation/security completions from starting payment.
  - An optimistic progress event hid a later command rejection → process rejection for the current attempt even after progress.
  - A rejected cancellation only reset a flag → keep the typed failure in processing state and show user-safe guidance with retry.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** The finding that justified a second, independent reviewer. The store was keyed by the bill, not by the execution, so a cancelled attempt could finish its retry with an old transaction and amount, and Flutter could consume another bill's progress. Codex proposed an attempt id across Flutter and Android (wire schema 2); I approved the complete plan after reviewing it, and I verified the fix. [confirm how: the regression tests, the emulator runs, the release APKs that install and pay]
- **Result:** 844 Dart tests, 220 JVM tests, clean format/analyze, Android Lint without errors, retail and utility debug APKs. Release validation is blocked as described above. Commit: fix: isolate payment attempts across Flutter and Android.

---

### 14. Complete the handoff documentation — 2026-10-16
- **Tool / model:** OpenAI Codex, GPT-6
- **Goal:** finish the incomplete AI Insight Report, preserve the developer's README/appendix work, and distinguish automated validation from pending device checks.
- **Prompt (key part, verbatim):**
  > да, погнали
- **Context given:** approved review-fix plan; existing milestone history, README draft, appendix drafts, manual QA and actual follow-up tool output.
- **AI output (summary):** completed the three report sections on multi-tenancy, AI assistance and the corrected cross-attempt design; integrated the existing appendix drafts, updated the sequence diagram, and added schema-v2 manual regression scenarios. Preserved earlier emulator measurements and labeled them as historical rather than claiming a new phone run.
- **Assumptions & risks flagged by the agent:** no quantified development-time saving is invented; no 120 Hz or physical-device validation is claimed. Current debug APKs build, but release validation remains blocked by the stale generated integration_test registration and the approval rejection described in entry 13. A saved stale PendingIntent needs an instrumented device trigger; the JVM action test is the current evidence.
- **Corrections made (AI suggestion → problem → correction):** three report headings were still template comments despite a nearly finished project → filled them from actual implementation/history and review evidence; an old checklist that claimed every failure was visible is now explicitly historical and includes the follow-up defects and corrections.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** I asked for the handoff documents to be completed. The README and appendices written earlier by the first agent were kept and completed, not replaced. [confirm: you read them]
- **Result:** 844 Dart tests and 220 JVM tests pass, format/analyze clean, Android Lint has no errors, both debug APKs build. Documentation links and anchors pass after the final report edits. Six focused commits, with no push or history rewrite. Commit: docs: complete the review report and validation notes.

---

### 15. Clear the new Android KTX warning — 2026-10-16
- **Tool / model:** OpenAI Codex, GPT-6
- **Goal:** leave no newly introduced Android Lint warning in the notification-cancel change.
- **Prompt (key part, verbatim):**
  > да, погнали
- **Context given:** final Android Lint output and the existing core-ktx dependency.
- **AI output (summary):** used the already available String.toUri extension for the attempt-specific cancel Intent data. Its underlying Uri parsing is API 1; no dependency or permission was added.
- **Assumptions & risks flagged by the agent:** two existing version notes remain for deliberately pinned Gradle and core-ktx. Release validation remains blocked as recorded in entry 13.
- **Corrections made (AI suggestion → problem → correction):** direct Uri.parse introduced UseKtx → use the existing extension instead of suppressing the warning.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Routine: a new Android Lint warning introduced by the notification-cancel change was cleared.
- **Result:** 844 Dart tests, 220 JVM tests, zero-issue Flutter analysis, clean formatting and both rebuilt debug APKs. Android Lint: zero errors, only the two pre-existing pinned-version warnings. Commit: chore: clear the Android KTX lint warning.

---

### 16. Validate release APKs after authorized plugin regeneration — 2026-10-16
- **Tool / model:** OpenAI Codex, GPT-6
- **Goal:** resolve the release-validation blocker recorded in entry 13 and build current schema-v2 APKs for both brands.
- **Prompt (key part, verbatim):**
  > да, давай попробуем
- **Context given:** explicit approval to let Flutter regenerate GeneratedPluginRegistrant.java through ordinary release builds; previous stale integration_test registration failure; Android native rules and review checklist.
- **AI output (summary):** ran flutter build apk --release --flavor retail and the corresponding utility command without --no-pub. Flutter refreshed its own plugin registration; the release registrant no longer references the dev-only integration_test plugin. Both builds succeeded without manually editing generated files. Updated the current validation status in the AI Insight Report, review appendix and channel documentation; retained the earlier log entries as historical records.
- **Assumptions & risks flagged by the agent:** these are locally built review APKs with the existing debug signing configuration. No signing settings, dependencies, iOS files or source code changed. Physical-device, rapid cancel/retry, stale-notification and high-refresh-rate checks remain pending in Manual QA; successful compilation does not establish those results.
- **Corrections made (AI suggestion → problem → correction):** the initial --no-pub release attempt reused a stale dev-plugin registration → the developer authorized standard Flutter regeneration, and ordinary release build commands succeeded. No manual generated-file workaround was needed.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Release validation was blocked by a stale generated plugin registration for the dev-only test plugin. I explicitly approved letting Flutter regenerate its own files, and the normal release commands then built both brands' schema-v2 APKs.
- **Result:** retail release APK: 45,345,302 bytes; utility release APK: 45,342,654 bytes, both under build/app/outputs/flutter-apk/. Release Android Lint: zero errors and the same two existing pinned-version warnings. Documentation links and anchors pass. The earlier 844 Dart tests, 220 JVM tests, format/analyze and debug-build checks remain the evidence for unchanged source code. Commit: docs: record successful release validation.

---

### 17. Package a profile APK for manual phone installation — 2026-10-16
- **Tool / model:** OpenAI Codex, GPT-6
- **Goal:** provide a standalone APK after the phone's ADB installation setting required a manufacturer account.
- **Prompt (key part, verbatim):**
  > может просто собрать билд и я его на телефоне установлю?
- **Context given:** the phone is Android arm64; profile mode preserves the demo panel and brand switcher; existing APK signing and packaging rules.
- **AI output (summary):** built Retail with flutter build apk --profile --flavor retail --target-platform android-arm64 and copied it to the ignored dist/retail-profile-arm64.apk. Verified the APK signature with apksigner and inspected its manifest and ABI with aapt: package com.hypertenant.secure_payment_portal.retail, minSdk 24, targetSdk 36, arm64-v8a only, no testOnly attribute. No source, signing configuration or dependency changes were needed.
- **Assumptions & risks flagged by the agent:** profile was selected to retain manual QA controls. The user still needs to transfer the APK and approve installation through the phone's system UI; this build does not establish physical-device validation or guarantee that manufacturer restrictions will allow manual installation.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Installing over ADB on my phone needs a manufacturer account, so I asked for a standalone APK to install by hand. It is the profile APK in `dist/`, which the manual checklist on the phone starts from. [confirm]
- **Result:** signed profile APK, 27,252,703 bytes, SHA-256 3f77cfe64e0326764c2f774d20982816ab24e377dde08c50af08947789bec327. Build and documentation-link checks pass; prior source validation remains applicable because source code is unchanged. APKs remain untracked. Commit: docs: record manual-install profile APK.

---

### 18. Reassess the architecture after follow-up fixes — 2026-10-16
- **Tool / model:** OpenAI Codex, GPT-6
- **Goal:** assess the current architecture from the perspective of a senior test-task reviewer.
- **Prompt (key part, verbatim):**
  > а как бы ты сейчас оценил архитектуру?
- **Context given:** current composition root, brand and section configuration, domain use case and security policy, Riverpod flow, native worker/store/service, architecture tests and previous validation results.
- **AI output (summary):** subjective assessment of 8.5/10 for the assignment. Strengths are the dependency boundaries, configuration-driven branding, domain security policy, attempt isolation and testable native lifecycle. Discussion points are the bill ID living in brand screen configuration, the implicit cancellation contract of ConfirmPayment.isCurrent, and the need for device integration coverage of the Dart/native lifecycle scenarios in addition to unit tests.
- **Assumptions & risks flagged by the agent:** the assessment concerns the assignment's scope, not a production payment backend. Prior 844 Dart and 220 JVM test results remain historical evidence for unchanged source; the full suite was not rerun for this code-reading assessment. The user's reported 120 Hz behavior is encouraging but is not a captured frame-timing report.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** I asked for the assessment of the architecture that a senior reviewer of a test task would give, after the fixes. It scored the assignment 8.5 out of 10 and raised three discussion points (the bill id living in the brand's screen configuration, the implicit cancellation contract of `ConfirmPayment.isCurrent`, device integration coverage of the lifecycle), which led to entries 19 to 21. I take the score as an opinion, not as evidence.
- **Result:** no application changes. Recorded the architecture assessment and checked documentation links. Commit: docs: record follow-up architecture assessment.

---

### 19. Separate payment requests from brand layout — 2026-10-16
- **Tool / model:** OpenAI Codex, GPT-6
- **Goal:** let the host select an order independently of white-label presentation.
- **Prompt (key part, verbatim):**
  > давай
- **Context given:** approved architecture-completion plan; branding, testing and review rules.
- **AI output (summary):** PaymentScreenConfig now contains only sections. App-owned BrandRegistration holds the initial demo request; selectedPaymentIdProvider exposes explicit host selection through the feature's independent paymentIdProvider. Default requests follow demo brand switching, while an explicit request survives a theme/layout switch and does not reload unnecessarily. Adapted existing fixtures and added request-selection/data-loading regressions.
- **Assumptions & risks flagged by the agent:** app demo defaults still differ by registration, but features and BrandConfig contain no order selection. An explicit order is not replaced when the user changes the demo brand. Documentation explaining the previous wiring will be synchronized in the final approved step.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Codex proposed separating the payment request from the brand layout: a brand now declares only the screen's layout and the host selects the order. I approved the concrete plan after reviewing it.
- **Result:** 849 Dart tests pass; formatting and Flutter analysis are clean. Commit: refactor: separate payment requests from brand layout.

---

### 20. Make confirmation cancellation and demo replay explicit — 2026-10-16
- **Tool / model:** OpenAI Codex, GPT-6
- **Goal:** express pre-acceptance cancellation without a presentation callback in the use-case contract and label the repeated fixture honestly.
- **Prompt (key part, verbatim):**
  > давай
- **Context given:** approved architecture-completion plan and existing attempt-isolation regressions.
- **AI output (summary):** introduced pure-Dart CancellationSignal/CancellationSource; the notifier owns cancellation, and ConfirmPayment checks the read-only signal around preparation and security awaits. The receipt action and notifier method now explicitly repeat the existing demo payment. Added direct use-case regressions for cancellation before preparation, during each await and after acceptance.
- **Assumptions & risks flagged by the agent:** cancelling confirmation does not stop an accepted payment; native attempt-scoped cancellation remains a separate operation. Presentation generation/mounted checks still protect stale state writes. The demo does not create a new backend order.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Proposed by Codex after the assessment: cancelling a pending confirmation becomes an explicit pure-Dart signal instead of a presentation callback in the use-case contract, and the receipt's repeat action is labelled as the demo replay it is. I approved the concrete plan after reviewing it.
- **Result:** 854 Dart tests pass; formatting and Flutter analysis are clean. Commit: refactor: clarify confirmation cancellation and demo replay.

---

### 21. Cancel obsolete confirmation before replacement details load — 2026-10-16
- **Tool / model:** OpenAI Codex, GPT-6
- **Goal:** close the gap between a host request changing and the new bill's asynchronous arrival.
- **Prompt (key part, verbatim):**
  > давай
- **Context given:** approved lifecycle coverage; the new independent bill-ID input and confirmation cancellation contract.
- **AI output (summary):** a stricter fakeAsync regression reproduced a stale native start (starts contained attempt-1) when only the request ID changed before the new details arrived. The flow now watches its request input, and its presentation-owned cancellation signal also checks that the original request still matches the host input. Domain only sees CancellationSignal. The latter check closes the interval before Riverpod rebuilds dependents.
- **Assumptions & risks flagged by the agent:** dependency invalidation alone is scheduled and did not close the race; the failing regression proved that. Native work already accepted remains governed by its attempt-scoped service lifecycle.
- **Corrections made (AI suggestion → problem → correction):** waiting for begin(newDetails) or a provider rebuild → old confirmation could start during replacement loading → bind cancellation to the current input ID as well as disposal, and test before new details exist.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** A gap found while implementing entry 19: the request could change after the old confirmation had checked it and before the replacement bill arrived. I accepted it as a necessary correctness fix within the approved plan. [confirm]
- **Result:** 855 Dart tests pass; analysis and formatting are clean. Commit: fix: invalidate confirmation when the host request changes.

### 22. Final delivery (Milestone 7): brands manifest, icons, CI, logger and a review pass — 2026-10-16
- **Tool / model:** Claude Code, claude-sonnet-5-5
- **Goal:** make the project deliverable: flavors created from a manifest, a launcher icon per brand, CI that builds a release APK per brand, a logger where errors would vanish, release builds that are documented as debug-signed, and a review pass over the whole repository against the checklist, with the documents brought up to date.
- **Prompt (key part, verbatim):**
  > Q4 change: use Java 21 (temurin) in CI, the same version you verified locally, instead of 17. Update the README requirement accordingly. Do install actionlint (brew install actionlint) and validate the workflow with it. No JDK 17.
  >
  > Logger: add a minimal Logger abstraction (dart:developer under the hood, no sensitive data) and use it where errors would otherwise vanish: the failure mapper when it produces UnexpectedFailure, and the platform data sources when they map PlatformException. That closes the observability gap and satisfies AGENTS.md §3.4. Do it as part of the review fixes.
- **Context given:** `AGENTS.md`, the review checklist, the multi-tenant rule (§6 "later work"), and an emulator and a clean clone to run things in.
- **AI output (summary):** `android/brands.json` read by Gradle in a loop (with readable failures for a duplicate, a malformed id, a wrong suffix, an empty name or a missing icon) and a test that keeps it equal to the registry; adaptive launcher icons with a themed layer plus legacy PNGs drawn from the same glyph path, with the colors tied to the tokens by a test; the GitHub Actions workflow (format, analyze, Dart and Kotlin tests, then a release APK per brand read from the manifest, Flutter 3.41.9, Temurin 21, every action pinned to a commit SHA) and `tool/build_release_apks.sh`; the official Gradle wrapper; a `Logger` with tests that plant a card number in every native message; Android Lint cleared and backups turned off; the iOS Pods integration; a test that checks every relative link and anchor in the documentation; a scratch third brand; the scan dwell timing extracted into `VerdictHold`; the README, the appendices and the demo script.
- **Assumptions & risks flagged by the agent:**
  - **The workflow has been validated, not run.** `actionlint` is clean and the `verify` and `build` jobs were run step by step in a clean clone, but the first real run is on GitHub.
  - **The icons were only seen on API 36.** The legacy PNGs for API 24 and 25 were checked by looking at them and by their dimensions and colors, with no older emulator.
  - **A second agent worked in the same working tree** while this session was stopped by a usage limit: it committed 13 times (entries 09 to 21), including my then-uncommitted README and appendices, and left its own integration-test work uncommitted. The documents were reconciled afterwards, not rewritten; where they disagree with what was approved, that is called out in the final report.
  - **The DRAFT developer reviews are the developer's voice** written by the agent, limited to recorded decisions.
- **Corrections made (AI suggestion → problem → correction):**
  - **`./gradlew testDebugUnitTest` as a CI step, and in the README** → Flutter git-ignores the wrapper and only creates it during a build, so a fresh clone had no `./gradlew`: the Kotlin step would have failed on the first push. Found only by running the job in a clean clone. The wrapper is now committed, generated by Gradle itself: the jar Flutter copies identifies itself as Gradle 2.10 and does not match the published checksum, and the distribution is pinned by SHA-256.
  - **A first Retail icon that read as a padlock** (a closed arch over a rectangle) → seen in a rendered PNG, redrawn as a tapered bag with the handle looping through it.
  - **Android Lint on the release variant through raw Gradle** → fails to compile, because `flutter pub get` regenerates the plugin registrant with the dev-only test plugin and only `flutter build --release` rewrites it. A tooling order, not an app bug; documented in the rule.
  - **A Gradle test that "passed" for a broken rules file** → the file was not a declared input of the test task, so Gradle reported the task up to date (the same trap as the manifest in entry 07). Declared; the mutation now fails.
  - **A mutation check that hung** → a zero-length periodic timer under fake time loops for ever. Each mutant now runs under a timeout, and a hang counts as caught. Several of my search patterns also missed because `dart format` had re-wrapped the line; scripted edits assert that they applied.
  - **Tests stricter than the rule** → a scratch third brand showed that an exact registry list and a distinct bill per brand would force an edit to a test when a brand is added. Relaxed, with the reason in a comment.
  - **The scan dwell timing inside the notifier** → 243 lines, at the review threshold. Extracted into `VerdictHold`, and the extraction itself turned up the hanging mutant.
  - **Logging the error** → the first thought was to log the error object; its text could carry anything. The logs carry the error's type, a code, a method name and a stack trace, never a message or an argument, and a test enforces it.
  - **`allowBackup="false"` alone** → Lint says it is deprecated on Android 12 and wants data-extraction rules, then asks for `fullBackupContent` as well. Both attributes are set, the one remaining redundant warning is ignored with its reason, and the manifest test checks every domain is excluded.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Approved the plan with these answers: highlights 03, 07 and 08 and the insight report's correction from entry 02; APKs not committed (`dist/` and CI artifacts, attached to a GitHub Release by the developer); actions pinned by full commit SHA with the tag in a comment; Java 21 in CI instead of 17, the README requirement updated, `actionlint` installed to validate the workflow, no JDK 17; the format check also covering `integration_test` and `test_driver`; the icon design (a bag and a bolt, with a themed layer); the review result as an appendix; the launcher image only in the README for now, with a placeholder for the brand-switch GIF; profile builds for the demo; no version bump and no LICENSE. Added the `Logger` requirement as part of the review fixes. Committed the Flutter-generated iOS files so that the tool stops dirtying the tree.
- **Result:** commits `3d3a3a1`, `5116f06` (brands manifest), `982af33` (TODOs, JDK 21), `92cb8b1` (icons), `b008774` (CI), `8f580c2` (Gradle wrapper), `1826227` (Logger), `f9daecd` (Lint, backups), `8d3d906` (iOS Pods), `273632f` (link test), `e5adcfc` (relaxed tests), `dcffc6b` (pubspec), `2dbdce4` (rule files), `21f29e9` (`VerdictHold`), then the documents. A scratch third brand: one config file, one registry line, one manifest entry, one icon folder, all tests green and an APK built, nothing under `lib/features` or `lib/core`.

### 23. Finish the device suites: payment flow test, lifecycle check, attribution — 2026-10-16
- **Tool / model:** Claude Code, claude-sonnet-5-5
- **Goal:** turn the second agent's uncommitted device work into committed, documented, stable suites, make the history attribute the second agent's commits, and leave the delivered APKs matching the code.
- **Prompt (key part, verbatim):**
  > Attribution: the 13 commits from the Codex session (d3f4a68..94d6ac1) have no Co-authored-by trailer, unlike yours. Nothing is pushed, so add "Co-authored-by: OpenAI Codex <noreply@openai.com>" to exactly those commits (rebase or filter-branch over that range only). Don't change the messages otherwise, or authorship and dates.
  >
  > tool/test_payment_lifecycle.py (+ payment_lifecycle_support.py): fix the uiautomator dump race (wait for the dump file / retry with a bounded timeout, no fixed sleeps if avoidable). Then prove stability: 5 consecutive green runs per flavor. Only then commit. If it can't reach 10/10, keep only the reliable scenarios and document the gap.
- **Context given:** the uncommitted files, the earlier run in which the lifecycle script passed on Retail and failed once on Utility, the repository's test conventions, and an emulator.
- **AI output (summary):** The 13 commits were rewritten in place with one trailer each (trees, authors, author and committer dates and subjects identical; the other four messages byte-identical). `integration_test/payment_flow_test.dart`, its harness and `test_driver/payment_integration.dart` got the header documentation the other device test has, and were committed. `tool/test_payment_lifecycle.py` now runs every brand from one command, and its `uiautomator` dump is retried within a bounded timeout. Both suites are documented (README, `docs/MANUAL_QA.md`, the testing rule, `AGENTS.md`) as emulator-only and outside CI. The stray `refs/codex/turn-diffs/*` ref was deleted, and the APKs in `dist/` were rebuilt from the current tree.
- **Assumptions & risks flagged by the agent:**
  - **Stability is evidence, not proof.** Five consecutive runs of the whole suite (Retail and Utility, two scenarios each: 10 of 10 flavor runs, 20 scenario passes) on one emulator image (API 36) passed after the fix. The failure it fixes was intermittent, so the retry was also exercised directly by injecting the failures that occurred (a missing dump file, an unreadable file, a dump that never works).
  - **Emulator only.** Neither suite can say how a notification looks, what a lock screen shows, or what another vendor's system does, and neither covers a process killed by the system. They complement the phone checklist and do not replace it.
  - **Not in CI**, because CI has no device; the README, the workflow comment and the checklist say so.
  - The history rewrite changed the hashes of the 13 commits and of the four after them, before any push.
- **Corrections made (AI suggestion → problem → correction):**
  - **The failure looked like a bad `cat`** (the traceback ended there) → the cause was `uiautomator dump` writing no file while the screen animated or an Activity was being replaced. Retrying the `cat` alone would have kept a stale file readable, so the old dump is removed before each attempt, a failed dump and a torn file are both retried, and the final error carries the last message from the tool.
  - **"Each takes about a minute per brand"** in my first draft of the README → the Flutter test takes about half a minute for both brands and the lifecycle check about forty seconds per brand; reworded to "a minute or two".
  - **The profile APK in `dist/`** → built at 12:34, before the last three code commits of the second agent (13:11 to 13:33), so it did not match HEAD. Rebuilt, signature checked, installed on the emulator and a payment run from it. The release APKs rebuilt to byte-identical checksums, so the build is reproducible here.
- **Developer review (DRAFT, written by the agent from the developer's recorded decisions; edit in your own words):** Asked that the second agent's uncommitted device tests be finished and committed if they ran green on the emulator (they passed 5 of 5), and that the lifecycle script's `uiautomator` race be fixed with a bounded wait or retry, proven by five consecutive green runs per flavor before it was committed, keeping only reliable scenarios otherwise. Required the README and the manual checklist to say how to run the suites and that they are not in CI, a one-line purpose header on each Python file and one command that runs the suite. Asked for the second agent's 13 commits to carry its `Co-authored-by` trailer, for the stray ref to be deleted, and for the delivered APKs to match the code.
- **Result:** commits `5a4fe9b` (payment flow device test), `18b1786` (lifecycle check and the dump retry), then the documentation. Five of five full-suite runs green on both flavors.

---
