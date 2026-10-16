# AI Prompt Log

Three interactions that show how this project was steered: context, my prompt, what the AI proposed, my review and decision,
and the outcome. The complete record is the [working log](appendix/working_log.md); the main findings are in the
[AI Insight Report](AI_INSIGHT_REPORT.md). All three are from the milestones written with Claude Code (`claude-sonnet-5-5`).

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
- **My review and decision.** I read the plan together with a second AI assistant I used as a reviewer, and rejected two
  shapes before any code existed. `Failure extends Result<Never>` relied on covariant generics and a non-sealed extension
  point, which would have made failure switches only partly exhaustive and was hard to explain; a plain
  `Success | Err(Failure)` with one sealed failure family per feature is conventional and exhaustive where it matters. One
  `SecurityRepository` mixed two responsibilities — reading device status and protecting the window — so I split it into
  `SecurityStatusRepository` and `SecureWindowController` (interface segregation): the secure screen needs only the second,
  the payment policy only the first. I accepted the split of the bill backend from payment processing, because only
  processing is later replaced by native code, and answered the policy questions: an unverifiable root blocks payment
  (fail-closed), and a recording that starts after the payment is authorised does not cancel it.
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
- **My review and decision.** I approved `shortService` alone, an explicit permission request and generic notification text,
  and changed two things. Cancel from the notification became a non-exported broadcast receiver, so it works whether or not
  the service is still alive and is not subject to service-start restrictions. And I changed the process: instead of stopping
  for me at every device check, the agent runs every `adb` step itself and collects only what genuinely needs a person into
  one checklist that I run on a phone at the end. That is what let the device, not the plan, have the last word on the
  notification order.
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
- **My review and decision.** I changed the plan in two places. The real device check takes 0.1–0.5 s, so the animation would
  only flash, and a reviewer installing the release APK — which has no demo panel — would never see it. Instead of an
  arbitrary delay, the verdict waits until the sweep completes one full revolution, derived from the brand's own period; a
  short, visible security check is also a common trust-building pattern in payment apps. I clamped the period to 1.6–3 s,
  because 0.96 s would look frantic for the "professional" brand, and asked for a profile-mode spike before building the
  measurement harness. Whether 1.6 s feels right is a subjective tuning point; the phone run confirmed the scan is smooth at
  120 Hz but did not judge its speed, so I left the clamp as is.
- **Outcome.** The hold is a timer in the payment flow, off for reduced motion, so Pay and the card never disagree. Rather
  than report only the half of the measurement that looked good, the AI added two references to the harness, Material's
  spinner and a layer that draws one dot, which showed the same raster numbers: that is the emulator's swap path, not the
  drawing. The scan costs 1.07 to 1.18 ms of UI thread per frame (the one-dot floor 0.92 to 1.08, the spinner 1.40). Nothing
  is claimed for 90 or 120 Hz. On the phone the performance overlay showed 120 FPS with no visible drops, but the harness was
  not run there; Utility's 1.6 s speed was not checked.
