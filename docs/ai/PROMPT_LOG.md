# AI Prompt Log

Three interactions that show how this project was steered: context, my prompt, what the AI proposed, my review and decision,
and the outcome. Significant decisions are explained in commit messages; the main findings are in the
[AI Insight Report](AI_INSIGHT_REPORT.md). All three are from the milestones written with Claude Code (`claude-sonnet-5-5`).

## 1. The plan gate changed the architecture before any code existed

Milestone 2: [Result and Failure](https://github.com/MaximLisovy/secure_payment_portal/commit/056a8ad), [segregated security interfaces](https://github.com/MaximLisovy/secure_payment_portal/commit/977790c) and [payment domain](https://github.com/MaximLisovy/secure_payment_portal/commit/233b355).

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

Milestone 5: [foreground service](https://github.com/MaximLisovy/secure_payment_portal/commit/d0505a3) and [corrected notification order](https://github.com/MaximLisovy/secure_payment_portal/commit/52cb030).

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

## 3. An emulator experiment refuted the recording hypothesis

[Recording experiment and corrected finding](https://github.com/MaximLisovy/secure_payment_portal/commit/4f54e15); [device evidence](../platform_channels.md#recording-callback-while-the-window-is-secure-defense-in-depth).

- **Context.** The phone's saved recording showed a black app area, but no recording block had appeared. The proposed
  explanation was that FLAG_SECURE excluded the window from capture and therefore silenced the visibility callback.
  That was a hypothesis; the phone maker's recorder could also behave differently from Android's stock recorder.
- **My prompt (key part, verbatim).**
  > M4-4 is tested: I checked the saved screen recording on the phone — the app area is black. Update M4-4, the M4-5 finding
  > and platform_channels.md: FLAG_SECURE is device-verified against recording; the silent callback is consistent with the
  > window being excluded from the capture. Keep your OEM-recorder caveat until the emulator experiment settles it.
  >
  > If you can, run the emulator experiment from my previous message (stock Screen record tile via uiautomator, with
  > FLAG_SECURE on, then off in a throwaway build that is never committed) and update the finding with the result.
- **What the AI had written.** The documents repeated the window-exclusion explanation as likely while marking it as a
  hypothesis. The saved-recording result established capture protection, but it did not explain the silent callback.
- **My review and decision.** I asked for the stock recorder comparison with the flag on and off, using a throwaway build
  that must never be committed. I kept the OEM-recorder caveat rather than accepting the hypothesis as established.
- **Outcome.** On a Pixel_9 API 36 emulator, the recording block appeared in all four flag-on runs and all three flag-off
  runs, and cleared after recording stopped. Screenshots and the sampled saved-video frame were black with the flag on and
  visible with it off. This refuted the claim that FLAG_SECURE necessarily silences the callback. The documents were
  corrected: an OEM-recorder difference fits the phone observation but remains unproven; only the stock “Record this screen”
  mode was tested. No throwaway code was committed. The lesson is to test the causal explanation separately from the
  observed result and revise the explanation when the experiment contradicts it.
