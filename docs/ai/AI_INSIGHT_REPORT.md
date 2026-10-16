# AI Insight Report

## 1. How the multi-tenant config is structured
<!-- BrandConfig → tokens (ThemeExtensions) + feature configs (sections) → registry resolved from appFlavor.
     Steps to add brand #3. -->

## 2. How AI accelerated development
<!-- Rules-first setup (AGENTS.md + .agents/rules), plan-before-code workflow, what was delegated,
     time saved, how output was verified (analyze/tests/profiling). -->

## 3. A sub-optimal AI solution and how I corrected it
<!-- Pick the strongest entry from PROMPT_LOG.md: AI suggestion → problem → correction → why it matters. -->

## 4. Performance evidence

The security scan is a `CustomPainter` radar (a sweep and three staggered pulses) in `lib/core/design_system/scan/`. The goal: the display's own refresh rate, no widget rebuilt per frame, and nothing repainted outside the scan's own layer.

**What makes it cheap, and how each claim is checked.**

| Claim | How it is checked |
|---|---|
| No widget rebuilds while the scan runs | a test pumps 60 frames and asserts that `debugOnRebuildDirtyWidget` fired for nothing, for the primitive and for the whole security card |
| Only the moving layer repaints | the repaint boundary's own counters: the moving layer's asymmetric paint count rises once per frame, its symmetric count and the counts of the still layer and of the page layer do not move; a probe painter beside the scan is never painted. Removing the boundary, or adding a `setState` per tick, makes these tests fail (both were tried) |
| Speed does not depend on the frame rate | the phase is elapsed time over the period: 600 ms of a 2.4 s period gives 0.25 at 120, 50 and 10 frames per second |
| The loop has no seam | the maths is periodic by construction (documented in `scan_math.dart`) and tested: the sweep turns by exactly 2π per period, and every pulse is invisible on both sides of the wrap |
| `paint()` allocates nothing | the paints are fields, colours come from a palette built once per style, the sweep shader is built once, geometry once per size (counters in tests); no `saveLayer`, clip, blur or shadow (asserted on a recording canvas). The frame timing run adds the garbage collection count as a check |
| The ticker lives exactly as long as the scan | `transientCallbackCount` is 0 once the verdict is shown, after the page is left, and with reduced motion |

I ran mutation checks on the maths, the painters, the widget, the flow and the summary tool (change the code, see a test fail). Four mutants first survived and each got a test (the fractional part of a negative number, a painter rebuilt when only the reduced-motion setting changes, a timer left running after the page was left, a box whose size was read from the constant under test); one is left, and it is equivalent (it changes a condition that can never be true in the state it guards).

**Frame timing.** `integration_test/scan_performance_test.dart`, `flutter drive --profile --no-dds`, every registered brand, each measured three times for 8 s after a 2 s warm-up, and the median reported. Four variants per brand: the real app with the scan running (`scan-in-app`), the scan alone on an empty page (`scan-alone`), Material's own `CircularProgressIndicator` alone on an empty page (`spinner-alone`, what a stock animated widget costs), and a layer that draws one dot per frame (`floor-alone`, the least any animating layer costs on this device, which the emulator needed to be read at all).

| Brand | Variant | FPS | Build (ms): avg / p90 / worst | Raster (ms): avg / p90 / worst | Frames over 16.67 ms (build / raster) | New-gen GCs |
|---|---|---|---|---|---|---|
| retail | floor-alone | 59.9 | 1.08 / 1.71 / 8.66 | 13.60 / 19.52 / 53.30 | 0 / 149 | 2 |
| retail | **scan-alone** | 59.4 | 1.07 / 1.83 / 6.04 | 13.69 / 19.26 / 28.41 | 0 / 155 | 2 |
| retail | **scan-in-app** | 60.3 | 1.15 / 1.84 / 6.92 | 15.98 / 19.58 / 54.06 | 0 / 212 | 2 |
| retail | spinner-alone | 59.9 | 1.41 / 2.15 / 7.22 | 14.87 / 19.26 / 33.91 | 0 / 187 | 6 |
| utility | floor-alone | 59.9 | 0.92 / 1.46 / 6.42 | 16.41 / 19.13 / 28.33 | 0 / 210 | 2 |
| utility | **scan-alone** | 59.9 | 1.12 / 1.80 / 10.44 | 15.20 / 19.74 / 39.05 | 0 / 190 | 2 |
| utility | **scan-in-app** | 59.1 | 1.18 / 1.97 / 10.51 | 16.39 / 19.55 / 73.83 | 0 / 211 | 2 |
| utility | spinner-alone | 59.4 | 1.40 / 2.32 / 10.07 | 16.34 / 19.18 / 59.12 | 0 / 194 | 6 |

Pixel_9 emulator (Android 16, API 36, arm64, host GPU), **profile build**, 60 Hz display, 8 s recorded per run, median of 3 runs. `floor-alone` is a layer that repaints every frame and draws one dot: the least an animating layer can cost on this device.

What the numbers say, and what they do not:

- **UI thread.** The scan costs 1.07 to 1.18 ms per frame on average (p90 under 2 ms), against 0.92 to 1.08 ms for the one-dot floor and 1.40 ms for Material's own spinner. It adds about 0.1 to 0.2 ms to the least possible, and is cheaper than a stock widget. No frame went over the 16.67 ms budget on the UI thread in any run.
- **Allocation.** Two new-generation garbage collections in 8 s, the same as the floor, against six for the spinner (twelve in an earlier run of the same harness without the floor). `paint()` does not allocate in any way a collector would notice.
- **Steady rate.** 59.1 to 60.3 frames per second delivered for every variant, on a 60 Hz display.
- **Raster time on the emulator tells nothing about the scan.** The floor, one dot per frame, takes 13.6 and 16.4 ms to rasterise on average, and about 150 to 210 of its roughly 480 frames are over budget, the same as the scan and the spinner. The emulator's host-GPU swap path sets that floor, not the drawing. The honest reading is that the scan adds nothing measurable on top of it, not that rasterising is cheap on a phone. For the same reason the 30 to 75 ms worst frames, which every variant has including the floor, are emulator hitches and not the scan.
- **Noise.** Run to run, and brand to brand for the identical floor, raster averages move by about 3 ms, so differences under that are not differences. A first complete run (without the floor) gave the same picture: scan 1.02 to 1.16 ms on the UI thread, 2 to 4 collections, the spinner 12.
- **Not claimed.** Nothing about 90 or 120 Hz, a real GPU, thermal behaviour or a low-power mode. Those are `M6-6` to `M6-10` in `docs/MANUAL_QA.md`, to be pasted here when the phone run is done.


**Design note: the verdict waits for a revolution.** A real device check takes a fraction of a second, so a scan that ran only for the check would be a flash that nobody sees, least of all in a release build with no demo panel. The payment flow therefore holds its verdict until the end of the current revolution of the sweep: `max(actual check time, one period)`, rounded up to the end of the revolution the check finished in. The wait is the brand's own period (four times `motion.slow`, held between 1.6 s and 3 s), so there is no number to configure and no brand check; the cost is that Pay is enabled 1.6 to 2.4 s after the check starts, and a check that takes 2.5 s on a 2.4 s period is shown at 4.8 s. A short, visible check is also a common way to make a security step feel real. Three limits keep it honest: it is not applied for a user who reduced motion (nothing sweeps), not to the second check made when Pay is pressed (the payment is not delayed), and not in tests. The hold lives in the flow's notifier as a timer, not in the animation: Pay and the card read the same state, so they can never disagree, and the tests need no real clock. The animation and the timer start within a frame of each other, and the sweep keeps turning through the fade, so the revolution completes on screen.

## 5. Scaling path (described, not implemented)

The design targets a handful of brands: two today, comfortably up to about ten. Past that, two changes would pay off. They are described here on purpose and are **not implemented**, because building them now would add machinery that two brands do not need.

**10+ brands: tokens as data.** Brand tokens move out of Dart into JSON design tokens exported from Figma. They are checked against a JSON schema and turned into `BrandTokens` by code generation, so a new brand is data plus assets rather than a hand-written `const BrandConfig`. The current code already allows this. `BrandTokens` is a plain, value-equal bundle of four small extensions. `ThemeFactory` is a pure function of it. Nothing outside `BrandRegistry` knows how a brand is produced, so a generator would emit the same `BrandConfig` values the registry holds today. The contrast table and the all-brands tests already run over every registered brand. They are the safety net that keeps a token change made by a non-developer from shipping an unreadable brand. A small generator script needs no new package. A package such as `build_runner` would need approval first, under the rules in `AGENTS.md`.

**Separate teams or release cycles: a monorepo.** Pub workspaces with shared `core` and feature packages, and a thin app shell per brand (flavor, `BrandConfig`, assets). This is cheap here because the dependency rule is already one-directional: `core` imports nothing, features import `core` (and another feature's public domain barrel), brands import `core`, and only `app` imports `brands`. Features never import `brands` or `app`, so each folder can become a package without untangling anything.

**Out of scope: runtime multi-tenancy.** A tenant chosen at login, with the theme served from a backend, would replace compile-time flavor resolution with a runtime lookup and remote tokens. That brings offline behaviour, caching and the trust placed in remote configuration, none of which this module addresses.

## 6. Payments in production: idempotency and reconciliation (described, not implemented)

Payment processing here is a simulation with no server, so nothing moves money and a lost payment costs nothing. The foreground service and the progress store are built so that the cheap failures are handled: one payment at a time, a start that races another is refused, a cancel and a finish that race have one winner, and the state survives the app being backgrounded or swiped away. What they do **not** survive is the process being killed (force-stop, out of memory, the user stopping the app from the active-apps list). The payment state lives in memory, the service is not sticky on purpose, and the app comes back with nothing running. Against a real payment provider that is the dangerous case, because the charge may have gone through while the app has no record of it, and the natural reaction of the user, to press Pay again, is a double charge.

**Idempotency key.** One key per user intent (one bill, one decision to pay), created before the first network call and stored before it is sent, so it survives a kill. Every attempt for that intent carries the same key (an `Idempotency-Key` header or the provider's equivalent), and the server returns the original outcome for a key it has already seen instead of charging twice. A retry after a timeout, a second tap, and a relaunch after a crash all become safe because they all send the same key. The key identifies the intent, not the attempt: a fresh key is created only when the user starts over knowingly, for example after a confirmed decline.

**A durable intent record and a third outcome.** Before the call, a small record (key, bill id, amount in minor units, currency, created at, status `pending`) goes to app-private storage. It holds no card data and no token. It becomes `succeeded` or `failed` only on an answer from the server, never from a local timeout. The domain needs a state it does not have today, **outcome unknown**, the payment-side twin of the tri-state rule already used for platform facts (`detected`, `notDetected`, `unknown`): "the request left and no answer came" must not be collapsed into `failed`, because failed invites a retry and unknown must not.

**Reconciliation on launch and on resume.** For every `pending` intent the app asks the server for the status of that key and settles the record. Until it does, the bill cannot be paid again and the screen says that the payment is being checked. A server-driven signal (a push or a webhook that updates the backend, picked up by the poll) is a second route to the same answer. The reconciliation itself is a good fit for WorkManager, which survives a dead process, rather than for the foreground service.

**Where it plugs in.** The seams already exist. The real call replaces `SimulatedPaymentProcessor` behind the Kotlin `PaymentProcessor` port, or moves to Dart behind `PaymentRemoteDataSource`; a `PaymentIntent` entity and a local data source go behind the existing `PaymentRepository` interface; the flow state gains the unknown outcome; presentation changes only to show it. Two native limits change with a real call. `shortService` stops after about three minutes (the type would have to change, or the request continue on the server while the service only watches it), and a network call needs the failure mapping that the simulation's always-succeeding processor never exercised. None of this is built, because without a server the idempotency semantics could not be tested against anything real, and persistence for a simulated outcome would only look like safety.
