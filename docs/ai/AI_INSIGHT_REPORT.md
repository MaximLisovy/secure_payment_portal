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
<!-- Profile-mode frame times per brand (avg / worst build & raster), repaint rainbow / rebuild tracking notes. -->

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
