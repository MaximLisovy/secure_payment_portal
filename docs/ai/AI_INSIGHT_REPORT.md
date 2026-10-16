# AI Insight Report

## 1. How the multi-tenant config is structured

`BrandConfig` contains identity, four small token families (`BrandColors`, `BrandShape`, `BrandDensity`, `BrandMotion`) and a feature-owned `PaymentScreenConfig`. `BrandRegistry` alone reads `appFlavor`. The composition root overrides feature configuration and derives themes through one `ThemeFactory`. ThemeExtensions and Riverpod overrides (built on inherited widgets) provide the scalable pattern requested by the task.

Visual differences are token values. Structural differences are ordered section specs: Retail declares a summary and promo banner; Utility a summary and bill breakdown. `PaymentSectionRegistry` maps spec types to slivers in one lazy scroll view. A brand reusing these sections needs one config file, a registry entry, an `android/brands.json` entry and launcher resources. Neither feature code nor Gradle flavor logic changes. All-brands, contrast and manifest tests discover registered brands automatically. The earlier third-brand experiment is recorded in the [review appendix](appendix/review.md).

Features depend on pure-Dart entities, policies and repository interfaces. Data owns DTOs, channel parsing and failure mapping. DI constructs implementations; presentation owns flow state and widgets. Money uses integer minor units, uncertain security facts remain tri-state, and bill/root collections are immutable snapshots. Native plugins translate channels; plain Kotlin ports, store, session and worker coordinator own logic.

## 2. How AI accelerated development

Claude Code implemented the initial milestones under repository rules and approved plans. OpenAI Codex reviewed the code,
found defects and, with my approval, implemented the fixes: **13 commits, about 2,300 lines, including the attempt-id rewrite**.
I reviewed its plan and the smaller diffs, and verified the large change through tests and device runs. The
[working log](appendix/working_log.md) records corrections and the later fixes requested by two reviews; no exact time-saving
percentage is claimed, and [Manual QA](../MANUAL_QA.md) distinguishes historical phone observations from untested behavior.

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

**Second example: correcting payment execution identity** ([working log, entry 13](appendix/working_log.md#13-isolate-payment-attempts-across-flutter-and-android--2026-10-16)).
Codex found that transitions keyed by the bill's paymentId could let events from a cancelled attempt finish its retry.
With my approval, it implemented per-execution attemptId across Dart, the channel and the Kotlin store; I reviewed the plan
and smaller diffs, and verified the large rewrite through tests and device runs.
These IDs isolate local executions; durable backend idempotency and reconciliation remain unimplemented, as described in the
[production-payments appendix](appendix/payments-in-production.md).

Current automated validation: **888 Dart tests**, **226 Kotlin/JVM tests**, clean formatting and Flutter analysis, and both
flavor debug builds. Both release binaries also passed cross-brand strings checks. The review fixes have not been rerun on a
physical phone; the earlier phone run and its untested items remain in [Manual QA](../MANUAL_QA.md), and the new in-app frame
statistics have no phone measurements yet. The [review appendix](appendix/review.md#two-review-findings-and-approved-fixes)
records the consolidated findings and fixes without treating a passing suite as proof of correctness.

## Appendices

| | |
|---|---|
| [A. Performance evidence](appendix/performance.md) | what makes the animation cheap and how each claim is checked; frame timing on an emulator with a floor reference, and what the numbers do not say |
| [B. Scaling path](appendix/scaling-path.md) | what would change past about ten brands, described and not built |
| [C. Payments in production](appendix/payments-in-production.md) | durable backend idempotency and reconciliation, described and not built |
| [D. Final review against the checklist](appendix/review.md) | the whole repository checked item by item, with what was found and fixed |
| [Prompt Log](PROMPT_LOG.md) | the three interactions that best show how the work was steered |
| [Working log](appendix/working_log.md) | every significant interaction, with its corrections and the developer's recorded decisions |
