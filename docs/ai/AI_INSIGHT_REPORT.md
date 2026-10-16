# AI Insight Report

## 1. How the multi-tenant config is structured

`BrandConfig` contains identity, four small token families (`BrandColors`, `BrandShape`, `BrandDensity`, `BrandMotion`) and a feature-owned `PaymentScreenConfig`. `BrandRegistry` alone reads `appFlavor`. The composition root overrides feature configuration and derives themes through one `ThemeFactory`. ThemeExtensions and Riverpod overrides (built on inherited widgets) provide the scalable pattern requested by the task.

Visual differences are token values. Structural differences are ordered section specs: Retail declares a summary and promo banner; Utility a summary and bill breakdown. `PaymentSectionRegistry` maps spec types to slivers in one lazy scroll view. A brand reusing these sections needs one config file, a registry entry, an `android/brands.json` entry and launcher resources. Neither feature code nor Gradle flavor logic changes. All-brands, contrast and manifest tests discover registered brands automatically. The earlier third-brand experiment is recorded in the [review appendix](appendix/review.md).

Features depend on pure-Dart entities, policies and repository interfaces. Data owns DTOs, channel parsing and failure mapping. DI constructs implementations; presentation owns flow state and widgets. Money uses integer minor units, uncertain security facts remain tri-state, and bill/root collections are immutable snapshots. Native plugins translate channels; plain Kotlin ports, store, session and worker coordinator own logic.

## 2. How AI accelerated development

The [working log](appendix/working_log.md) records milestone prompts, approved plans, rejected alternatives and corrections. Agents helped scaffold boundaries, implement deterministic fakes, draft channel contracts, generate edge-case tests and investigate platform behavior. Repository rules constrained implementation; installed framework sources, compiler checks, emulator observations and independent review checked the output.

How the work was run: `AGENTS.md` and five topic rule files were written first and re-read before each task; every milestone began with a plan-only turn (files, layers, risks, numbered questions) that the developer approved, usually with changes, before any code; and the work landed as small commits, each passing formatting, analysis and the whole test suite, with both flavor builds as the gate for a milestone. The agents ran their own checks as well: they broke new code on purpose to see a test fail, drove the emulator through `adb` (notifications, services, recents, window flags), and ran the CI steps in a clean clone, which found that a fresh checkout had no `./gradlew`. The first eight milestones' log entries record 58 corrections, and the checks that need a person and a phone are collected in [Manual QA](../MANUAL_QA.md) rather than guessed. I also used a separate AI assistant (Claude, in a chat) as an architecture reviewer: I brought each plan and report there, compared alternatives — the official Flutter architecture guide against strict Clean Architecture, the white-label approaches in use today — and sent my decisions back to the coding agent; when its quota ran out, OpenAI Codex reviewed the code independently (see §3).

The benefit is concrete but not timed: shared fake/native contract suites, layering tests, automatic per-brand checks and focused JVM tests reduce repeated manual setup. No exact time-saving percentage is claimed. Independent review exposed gaps in the original passing suite, especially retries of the same bill and asynchronous preparation. Follow-up changes added regressions and full analysis/build checks in focused commits. One run on a physical phone (ZTE RedMagic 10 Pro, Android 16, 2026-10-16) covered the main device checks; what it did not cover is marked *not tested* in Manual QA.

## 3. A sub-optimal AI solution and how I corrected it

**Brand colours that passed their own test and failed on screen** ([working log, entries 01 and 02](appendix/working_log.md#01-white-label-foundation-milestone-1--2026-10-15)).

- **What the AI did.** Retail's vivid orange was the colour scheme's `primary`, and the agent's contrast test checked only
  the "on" pairs (white on orange, text on surface). The suite was green. But Material also uses `primary` as a foreground —
  text and outlined buttons, icons, the focus ring, progress, the cursor — where the orange measured about 2.6:1 on Retail's
  cream surfaces (text needs 4.5:1, UI 3:1). The agent found this from an emulator screenshot, not from its test, and
  proposed a new darker role applied component by component.
- **Why that was sub-optimal.** I reviewed the report with a second AI assistant that I used as an architecture reviewer,
  and two problems stood out. The test gave false confidence: it checked the pairs that were easy to name, not the ones the
  theme actually renders. And patching components one by one left `primary` vivid, so every widget nobody had themed yet
  (a Switch, a Checkbox, a Slider) would fail again in the next feature.
- **My correction.** Three decisions. (1) The test reads every foreground/background pair from the built `ThemeData`, for
  every registered brand — 4.5:1 for text, 3:1 for UI — plus a meta-test proving the old orange fails. (2) Invert the default:
  `ColorScheme.primary` is the accessible tone, and the vivid orange is applied explicitly only where a fill is meant (filled
  button, app bar), so an unthemed widget is readable by default. (3) A separate decorative outline role, exempt under WCAG
  1.4.11, so Retail kept its soft card edges while input borders stay at 3:1.
- **Result.** The wider table immediately found two more defects of the same kind (input borders at 1.3:1 and 2.3:1, a 2.4:1
  snackbar action), and later rejected a careless palette for a scratch third brand (4.41:1) before anything was built.
- **Lesson.** The AI fixed the symptom where it saw it. The better fix changes the default so the mistake cannot recur, and
  makes the test check what is actually rendered. That matters most in white-label, where the next brand's colours are chosen
  by someone else.

**Second example: an independent reviewer** ([working log, entry 13](appendix/working_log.md#13-isolate-payment-attempts-across-flutter-and-android--2026-10-16)).
When the first agent's quota ran out, I ran OpenAI Codex deliberately as an independent reviewer of the code written so far.
It found that the payment store keyed its transitions by `paymentId` — a bill, not an execution — so a cancel followed by an
immediate retry could let events from the old attempt complete the new one. It proposed a per-execution `attemptId` across
Dart, the channel contract and the Kotlin store. I reviewed the plan and approved it. Verification came from the new
regression tests and the full suites, the other agent's emulator runs and release-APK checks, and later the device tests of
the payment lifecycle on the real plugin and service. The lesson: a clean structure and a large test count had still not
tested a lifecycle boundary, and a second, independent reviewer found it. The attempt ID is not server idempotency or durable
recovery; the [production-payments appendix](appendix/payments-in-production.md) describes those unimplemented requirements.

Current validation: **855 Dart tests**, **220 Kotlin/JVM tests**, clean formatting and Flutter analysis, and Android Lint with no
errors. After explicit permission to let Flutter regenerate plugin registration, the ordinary release build commands resolved an
earlier stale integration-test registration failure without manual edits to generated files. The one phone run (ZTE RedMagic 10 Pro,
Android 16) and the checks it did not cover are in [Manual QA](../MANUAL_QA.md).

## Appendices

| | |
|---|---|
| [A. Performance evidence and the scan dwell](appendix/performance.md) | what makes the animation cheap and how each claim is checked; frame timing on an emulator with a floor reference, and what the numbers do not say; why the verdict waits for a revolution |
| [B. Scaling path](appendix/scaling-path.md) | what would change past about ten brands, described and not built |
| [C. Payments in production](appendix/payments-in-production.md) | idempotency keys and reconciliation, described and not built |
| [D. Final review against the checklist](appendix/review.md) | the whole repository checked item by item, with what was found and fixed |
| [Prompt Log](PROMPT_LOG.md) | the three interactions that best show how the work was steered |
| [Working log](appendix/working_log.md) | every significant interaction, with its corrections and the developer's recorded decisions |
