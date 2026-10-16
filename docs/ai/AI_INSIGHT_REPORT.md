# AI Insight Report

## 1. How the multi-tenant config is structured

`BrandConfig` contains identity, four small token families (`BrandColors`, `BrandShape`, `BrandDensity`, `BrandMotion`) and a feature-owned `PaymentScreenConfig`. `BrandRegistry` alone reads `appFlavor`. The composition root overrides feature configuration and derives themes through one `ThemeFactory`. ThemeExtensions and Riverpod overrides (built on inherited widgets) provide the scalable pattern requested by the task.

Visual differences are token values. Structural differences are ordered section specs: Retail declares a summary and promo banner; Utility a summary and bill breakdown. `PaymentSectionRegistry` maps spec types to slivers in one lazy scroll view. A brand reusing these sections needs one config file, a registry entry, an `android/brands.json` entry and launcher resources. Neither feature code nor Gradle flavor logic changes. All-brands, contrast and manifest tests discover registered brands automatically. The earlier third-brand experiment is recorded in the [review appendix](appendix/review.md).

Features depend on pure-Dart entities, policies and repository interfaces. Data owns DTOs, channel parsing and failure mapping. DI constructs implementations; presentation owns flow state and widgets. Money uses integer minor units, uncertain security facts remain tri-state, and bill/root collections are immutable snapshots. Native plugins translate channels; plain Kotlin ports, store, session and worker coordinator own logic.

## 2. How AI accelerated development

The [Prompt Log](PROMPT_LOG.md) records milestone prompts, approved plans, rejected alternatives and corrections. Agents helped scaffold boundaries, implement deterministic fakes, draft channel contracts, generate edge-case tests and investigate platform behavior. Repository rules constrained implementation; installed framework sources, compiler checks, emulator observations and independent review checked the output.

How the work was run: `AGENTS.md` and five topic rule files were written first and re-read before each task; every milestone began with a plan-only turn (files, layers, risks, numbered questions) that the developer approved, usually with changes, before any code; and the work landed as small commits, each passing formatting, analysis and the whole test suite, with both flavor builds as the gate for a milestone. The agents ran their own checks as well: they broke new code on purpose to see a test fail, drove the emulator through `adb` (notifications, services, recents, window flags), and ran the CI steps in a clean clone, which found that a fresh checkout had no `./gradlew`. The first eight milestones' log entries record 58 corrections, and the checks that need a person and a phone are collected in [Manual QA](../MANUAL_QA.md) rather than guessed.

The benefit is concrete but not timed: shared fake/native contract suites, layering tests, automatic per-brand checks and focused JVM tests reduce repeated manual setup. No exact time-saving percentage is claimed. Independent review exposed gaps in the original passing suite, especially retries of the same bill and asynchronous preparation. Follow-up changes added regressions and full analysis/build checks in focused commits. The physical-device checks remain separate and explicitly pending.

## 3. A sub-optimal AI solution and how I corrected it

**Brand colors that passed their own test and failed on screen** ([Prompt Log, entries 01 and 02](PROMPT_LOG.md)).

- **The AI's solution.** Retail's vivid orange was the color scheme's `primary`, and the contrast test checked only the "on"
  pairs (primary on its on-color, surface on its text). Everything passed.
- **The problem.** Material also uses `primary` as a *foreground*: text buttons, outlined buttons, icons, the focus ring,
  progress, the cursor, and every widget nobody themed (a Switch, a Checkbox). Orange on cream is 2.6:1 there, where text needs
  4.5:1 and UI 3:1. The test was blind to those pairs; the problem showed up on a device screenshot, not in the suite. The AI's
  first fix patched one component at a time and left `primary` vivid, so the trap stayed open for the next feature, and I
  pointed that out.
- **The correction.** A role split that I asked for: `ColorScheme.primary` is the accessible tone (`brandOnSurface`), and the
  vivid `brandPrimary` is applied explicitly, only where a fill is meant. Decorative borders got their own soft role
  (`outlineSubtle`, exempt under WCAG 1.4.11) so control borders could be held at 3:1. The test became one table of every color
  the components and the scheme defaults use, run for every registered brand, with tests that prove it still fails on the old
  vivid value and on a soft border used for a control.
- **Why it matters here.** In a white-label product the next brand is chosen by someone else, with colors the AI never saw. A
  safe default plus a table that runs for every registered brand means a low-contrast palette fails a test before it ships. In
  the final milestone that table rejected the careless colors of a scratch third brand (4.41:1 against 4.5:1) before anything
  was built.

**A second example, found by an independent reviewer** ([entry 13](PROMPT_LOG.md)). When the first agent's quota ran out I ran a
second agent (OpenAI Codex) on purpose as an independent reviewer, and it found a defect that the first agent's passing tests
had not. The payment store kept its atomic transitions keyed only by `paymentId`, but that ID is a bill, not an execution:
a cancelled attempt could finish its retry with an old transaction and amount, and Flutter could consume another bill's live
progress and hide `ALREADY_RUNNING` behind a processing state. The fix gives every execution a fresh `attemptId` across domain,
DTOs, commands, events, store, session and notification cancellation (the in-app wire schema is now version 2), makes the worker
coordinator cancel and join retired work, and lets Flutter drop obsolete confirmations and filter events by bill and attempt. I
approved the plan after reviewing it and verified the fix: regressions for late progress, stale notification cancellation, rapid
worker replacement, duplicate delivery, stale timeouts and a changed bill during preparation; the full suites; and both brands'
release APKs installed on an emulator and taking a payment. The lesson is that a clean structure and a large test count had not
tested a lifecycle boundary. The attempt ID is not server idempotency or durable recovery: the
[production-payments appendix](appendix/payments-in-production.md) describes those unimplemented requirements, and this task has
no backend and moves no real money.

Current validation: **855 Dart tests**, **220 Kotlin/JVM tests**, clean formatting and Flutter analysis, and Android Lint with no
errors. After explicit permission to let Flutter regenerate plugin registration, the ordinary release build commands resolved an
earlier stale integration-test registration failure without manual edits to generated files. The remaining device-only checks are
in [Manual QA](../MANUAL_QA.md).

## Appendices

| | |
|---|---|
| [A. Performance evidence and the scan dwell](appendix/performance.md) | what makes the animation cheap and how each claim is checked; frame timing on an emulator with a floor reference, and what the numbers do not say; why the verdict waits for a revolution |
| [B. Scaling path](appendix/scaling-path.md) | what would change past about ten brands, described and not built |
| [C. Payments in production](appendix/payments-in-production.md) | idempotency keys and reconciliation, described and not built |
| [D. Final review against the checklist](appendix/review.md) | the whole repository checked item by item, with what was found and fixed |
| [Prompt Log](PROMPT_LOG.md) | every significant interaction, with its corrections |
