# AI Prompt Log

Three interactions that show how this project was steered: context, my prompt, what the AI proposed, my review and decision,
and the outcome. The complete record is the [working log](appendix/working_log.md); the main findings are in the
[AI Insight Report](AI_INSIGHT_REPORT.md). All three are from the milestones written with Claude Code (`claude-sonnet-5-5`).

Only the parts marked **DRAFT** are not final: they are my review and decision, written by the agent from the decisions I gave
during the work. I will rewrite them in my own words.

## 1. The plan gate changed the architecture before any code existed

Milestone 2, [working log entry 03](appendix/working_log.md#03-domain-and-fake-data-for-payment-and-security-milestone-2--2026-10-15).

- **Context.** The domain layer for payment and security had to let the native modules of later milestones replace the fakes
  unchanged. A milestone starts with a plan-only turn and waits for approval.
- **My prompt (key part, verbatim).**
  > Milestone 2 — domain + fake data for payment and security. PLAN ONLY, no code yet. … Their interfaces must let the real
  > channel-based sources drop in later unchanged. … Wait for my approval.
  >
  > Approved, with two changes: 1. Result/Failure: drop "Failure extends Result<Never>" and the FeatureFailure extension point.
  > Use sealed Result<T> = Success<T>(value) | Err<T>(Failure failure) … 2. Interface segregation: split SecurityRepository
  > into SecurityStatusRepository … and SecureWindowController.
- **What the AI proposed.** `Failure` extending `Result<Never>`, with a non-sealed extension point for each feature's failures;
  one `SecurityRepository` for both reading the device status and protecting the window; and the bill backend split from the
  payment-processing source, which the request had described as one fake.
- **My review and decision (DRAFT).** I rejected the first two before a line was written: a sealed `Result<T>` with a sealed
  `Failure` family per feature, so that a `switch` over a feature's failures is exhaustive; and two small interfaces over one
  platform data source, so that the screen that only protects the window does not depend on reading status. I accepted the
  backend split, since only the processing is replaced by native code.
- **Outcome.** The payment flow, the Kotlin bridge and the tests were all built on those shapes; the milestone ended with 326
  tests and both flavors building. The same milestone shows the other half of the loop: the AI's own `async*` status stream
  could not be cancelled until its next event, which a test that hung found and a review would not have.

## 2. The device overruled the AI's plan, its comments and the rule file

Milestone 5, [working log entry 07](appendix/working_log.md#07-payment-foreground-service-milestone-5--2026-10-16).

- **Context.** A foreground service with a progress notification carries out the simulated payment, and every device fact was
  to be checked on an emulator with `adb` instead of assumed.
- **My prompt (key part, verbatim).**
  > Handle the notification Cancel action with a non-exported BroadcastReceiver (PendingIntent.getBroadcast, FLAG_IMMUTABLE)
  > that calls store.cancelIfRunning(), instead of PendingIntent.getService. Cancel then doesn't depend on the service being
  > alive and avoids any service-start restrictions. Keep the manifest guard in sync.
  >
  > Process change (Q11): don't stop for manual checks anymore. Run every adb step you can yourself on the emulator. Collect
  > everything that needs a human into docs/MANUAL_QA.md: one checklist grouped by milestone, each item with exact steps and
  > the expected result.
- **What the AI proposed.** A plan, its KDoc and the Android rule file that all said the same thing: post the final "Payment
  complete" notification, then stop the service. Cancel from the notification went through `PendingIntent.getService`.
- **My review and decision (DRAFT).** I made Cancel a non-exported broadcast receiver, so that it does not depend on the
  service being alive, and changed the process: the agent runs every `adb` step itself, and what needs a person goes into one
  checklist that I run once on a phone at the end. I also answered the plan's questions: `shortService` alone, an explicit
  permission request, generic notification text, and native processing that always succeeds.
- **Outcome.** On the emulator, `dumpsys notification` showed that posting the final notification before the service detached
  left it without its auto-cancel flag, so it could not be dismissed. The order was reversed and the plan, the KDoc and the
  rule were corrected; no test would have caught it. A plausible result ("instant success after swiping the app away") was a
  slow `uiautomator` dump, and was proved so. The milestone ended with 636 Dart and 207 Kotlin tests, an R8 release build, and
  the checks that need a person recorded as `M5-1` to `M5-12`.

## 3. A product rule from me, and an honest measurement

Milestone 6, [working log entry 08](appendix/working_log.md#08-the-security-scanning-animation-milestone-6--2026-10-16).

- **Context.** The security card's spinner was replaced by a `CustomPainter` radar, styled from each brand's tokens, rebuilding
  nothing, and measured on a device.
- **My prompt (key part, verbatim).**
  > Q3 changed: the verdict waits until the sweep completes at least one full revolution — max(actual check time, one period),
  > aligned to the end of the current revolution. No arbitrary config number: the dwell is derived from the brand's period.
  > Rationale: the real check takes 0.1–0.5 s, and graders running a release APK (no demo panel) would otherwise never see the
  > animation.
  >
  > Q5 adjusted: keep the period derived (slow × 4), but clamp it to [1.6 s, 3 s]. 0.96 s for Utility will likely look
  > frantic. Confirm in the rendered PNGs and adjust the clamp if needed.
- **What the AI proposed.** A scan shown only while the check runs, with no minimum time and a period of four times the
  brand's `slow` duration, unclamped (0.96 s for Utility). Its first raster measurements then looked like a failure: about 40 %
  of frames over budget.
- **My review and decision (DRAFT).** I changed the plan twice: the verdict waits for a full revolution, derived from the
  brand's own period, because a release build would otherwise never show the animation; and the period is clamped to 1.6 to
  3 s. I asked for a profile-mode spike first. Whether 1.6 s feels right cannot be decided from still images, so it is an open
  item for the phone.
- **Outcome.** The hold is a timer in the payment flow, off for reduced motion, so Pay and the card never disagree. Rather
  than report only the half of the measurement that looked good, the AI added two references to the harness, Material's
  spinner and a layer that draws one dot, which showed the same raster numbers: that is the emulator's swap path, not the
  drawing. The scan costs 1.07 to 1.18 ms of UI thread per frame (the one-dot floor 0.92 to 1.08, the spinner 1.40). Nothing
  is claimed for 90 or 120 Hz until the phone run.
