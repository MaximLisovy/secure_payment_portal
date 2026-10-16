# AI Insight Report

## 1. How the multi-tenant config is structured

`BrandConfig` contains identity, four small token families (`BrandColors`, `BrandShape`, `BrandDensity`, `BrandMotion`) and a feature-owned `PaymentScreenConfig`. `BrandRegistry` alone reads `appFlavor`. The composition root overrides feature configuration and derives themes through one `ThemeFactory`. ThemeExtensions and Riverpod overrides (built on inherited widgets) provide the scalable pattern requested by the task.

Visual differences are token values. Structural differences are ordered section specs: Retail declares a summary and promo banner; Utility a summary and bill breakdown. `PaymentSectionRegistry` maps spec types to slivers in one lazy scroll view. A brand reusing these sections needs one config file, a registry entry, an `android/brands.json` entry and launcher resources. Neither feature code nor Gradle flavor logic changes. All-brands, contrast and manifest tests discover registered brands automatically. The earlier third-brand experiment is recorded in the [review appendix](appendix/review.md).

Features depend on pure-Dart entities, policies and repository interfaces. Data owns DTOs, channel parsing and failure mapping. DI constructs implementations; presentation owns flow state and widgets. Money uses integer minor units, uncertain security facts remain tri-state, and bill/root collections are immutable snapshots. Native plugins translate channels; plain Kotlin ports, store, session and worker coordinator own logic.

## 2. How AI accelerated development

The [Prompt Log](PROMPT_LOG.md) records milestone prompts, approved plans, rejected alternatives and corrections. Agents helped scaffold boundaries, implement deterministic fakes, draft channel contracts, generate edge-case tests and investigate platform behavior. Repository rules constrained implementation; installed framework sources, compiler checks, emulator observations and independent review checked the output.

How the work was run: `AGENTS.md` and five topic rule files were written first and re-read before each task; every milestone began with a plan-only turn (files, layers, risks, numbered questions) that the developer approved, usually with changes, before any code; and the work landed as small commits, each passing formatting, analysis and the whole test suite, with both flavor builds as the gate for a milestone. The agents ran their own checks as well: they broke new code on purpose to see a test fail, drove the emulator through `adb` (notifications, services, recents, window flags), and ran the CI steps in a clean clone, which found that a fresh checkout had no `./gradlew`. The first eight milestones' log entries record 58 corrections, and the checks that need a person and a phone are collected in [Manual QA](../MANUAL_QA.md) rather than guessed.

The benefit is concrete but not timed: shared fake/native contract suites, layering tests, automatic per-brand checks and focused JVM tests reduce repeated manual setup. No exact time-saving percentage is claimed. Independent review exposed gaps in the original passing suite, especially retries of the same bill and asynchronous preparation. Follow-up changes added regressions and full analysis/build checks in focused commits. The physical-device checks remain separate and explicitly pending.

## 3. A sub-optimal AI solution and how it was corrected

The original store used atomic transitions keyed only by `paymentId`. Tests of a cancel racing a finish passed, but that ID represented a bill, not an execution. Independent review reproduced a cancelled attempt completing its retry with an old transaction and amount. Flutter could also consume another bill's live progress during confirmation and hide `ALREADY_RUNNING` behind a processing state.

The correction assigns a fresh `attemptId` to each execution across domain, DTOs, commands, events, store, session and notification cancellation. The shared in-app wire schema is version 2. The worker coordinator cancels and joins retired work, distinguishes duplicates from replacements and binds foreground cleanup to its current worker. Flutter invalidates obsolete confirmation, filters events by bill and attempt and preserves command rejection. Permission preparation finishes before the final security read, so a long prompt cannot preserve an old verdict.

Regressions cover late progress, success, failure and rollback after retry; stale notification cancellation; rapid worker replacement; duplicate delivery; stale timeouts; switching bills or disposing during preparation/security; and command failure after optimistic progress. Other fixes share pending window commands, reconcile overlapping ownership changes, and copy domain collections defensively. Structural cleanliness and a large test count did not replace testing lifecycle boundaries.

The attempt ID is not server idempotency or durable recovery. The [production-payments appendix](appendix/payments-in-production.md) describes those unimplemented requirements. This task has no backend and moves no real money.

Current validation: **855 Dart tests**, **220 Kotlin/JVM tests**, clean formatting and Flutter analysis, and Android Lint with no errors. Both schema-v2 debug and release APKs build. After explicit permission to let Flutter regenerate plugin registration, ordinary release build commands resolved the earlier stale integration-test registration failure without manual generated-file edits. APK validation and the remaining device-only checks are recorded in the [Prompt Log](PROMPT_LOG.md) and [Manual QA](../MANUAL_QA.md).

An earlier, smaller example of the same lesson ([entries 01 and 02](PROMPT_LOG.md)): the first brand colors passed their own contrast test and failed on a screenshot. Retail's vivid orange was the color scheme's `primary`, the test checked only the "on" pairs, and Material also uses `primary` as a foreground (text buttons, icons, the focus ring, every widget nobody themed), where orange on cream is 2.6:1. The AI's first fix patched one component at a time and left the trap open; the developer pointed that out. The fix was a role split (`primary` is the accessible tone, the vivid color is applied explicitly where a fill is meant) and one contrast table, run for every registered brand. In the final milestone that table rejected the careless colors of a scratch third brand (4.41:1 against 4.5:1) before anything was built.

## Appendices

| | |
|---|---|
| [A. Performance evidence and the scan dwell](appendix/performance.md) | what makes the animation cheap and how each claim is checked; frame timing on an emulator with a floor reference, and what the numbers do not say; why the verdict waits for a revolution |
| [B. Scaling path](appendix/scaling-path.md) | what would change past about ten brands, described and not built |
| [C. Payments in production](appendix/payments-in-production.md) | idempotency keys and reconciliation, described and not built |
| [D. Final review against the checklist](appendix/review.md) | the whole repository checked item by item, with what was found and fixed |
| [Prompt Log](PROMPT_LOG.md) | every significant interaction, with its corrections |
