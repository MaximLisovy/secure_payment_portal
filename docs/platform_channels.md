# Platform channel contract

Single source of truth for the Dart ↔ Kotlin bridge. Keep it in sync with
`lib/core/platform/channel_contract.dart` (Dart) and
`android/app/src/main/kotlin/.../bridge/Channels.kt` (Kotlin).
Update this file in the same change that alters the contract.

**Status.**

- **Security (`…/security`, `…/security/screen_recording`): v2, final.**
  Kotlin (`SecurityPlugin`) and Dart (`ChannelSecurityPlatformDataSource`) both
  exist. They were checked on a Pixel_9 emulator (API 36), as listed under
  [Verified on a device](#verified-on-a-device-security), and on a phone, as listed
  under [Verified on a phone](#verified-on-a-phone-2026-10-16). The one open check,
  what the recording callback does while the window is secure, was settled on the
  phone: **defense in depth** (below).
- **Payment (`…/payment`, `…/payment/progress`): v2, final.** The Kotlin
  foreground service (`PaymentProcessingService`, `PaymentServicePlugin`) and the
  Dart `ChannelPaymentPlatformDataSource` both exist, the Dart one passes the
  payment contract suite unchanged, and what `adb` could check on a Pixel_9
  emulator (API 36) is listed under
  [Verified on a device (payment)](#verified-on-a-device-payment). On the phone the
  live progress notification, Cancel and backgrounding during a payment were seen
  working. The items **not tested** on the phone (the permission prompt, the lock
  screen, swiping the app away, other API levels, battery saver) check Android's
  behavior around the contract, not the contract itself, so they do not hold the
  status back; each stays listed as *not tested* in [`docs/MANUAL_QA.md`](MANUAL_QA.md).

`bridge/Channels.kt` mirrors `lib/core/platform/channel_contract.dart` for both
halves; a Dart test (`test/core/platform/channel_contract_sync_test.dart`) fails if
they differ in a name, a key or a value.

All names start with `com.hypertenant.secure_payment_portal` (written `…` below).
They never depend on the `applicationId`, which differs per flavor.

## Channels

| Channel | Type | Method / event | Args | Returns / emits | Error codes | Min API notes |
|---|---|---|---|---|---|---|
| `…/security` | Method | `getSecurityStatus` | none | map: `schemaVersion`, `root`, `rootSignals`, `screenRecording`, `windowProtection` | `INTERNAL`, `UNAVAILABLE` | Root checks work on every supported API. Recording state is real on API 35+ and `unknown` below. |
| `…/security` | Method | `enableSecureWindow` | none | `null` | `UNAVAILABLE` (no Activity) | `FLAG_SECURE`, any API. Reference counted. |
| `…/security` | Method | `disableSecureWindow` | none | `null` | `UNAVAILABLE` | Balances `enableSecureWindow`; an extra call is ignored. |
| `…/security/screen_recording` | Event | recording changes | none | map: `schemaVersion`, `screenRecording` | — | API 35+ detection callback; below that it emits `unknown`. |
| `…/payment` | Method | `startPayment` | map: `schemaVersion`, `paymentId`, `attemptId`, `amountMinor`, `currency` | `null` once processing was **accepted** | `ALREADY_RUNNING`, `START_NOT_ALLOWED`, `INVALID_ARGS` | Foreground service started from a user action while the app is visible. |
| `…/payment` | Method | `cancelPayment` | map: `schemaVersion`, `attemptId` | `null` | `INVALID_ARGS`, `INTERNAL` | A stale attempt ID is a no-op. |
| `…/payment` | Method | `requestNotificationPermission` | none | string: `granted`, `denied` or `notRequired` | — (never fails) | Runtime permission from API 33; `notRequired` below. Called by the Dart data source before `startPayment`. |
| `…/payment/progress` | Event | payment progress | none | map: `schemaVersion`, `state`, plus the fields of that state | — | Fed by the service's process-wide state. |

Unknown method → `notImplemented`. Bad arguments → `INVALID_ARGS`. The engine never crashes.

## Payloads

Flat maps of primitives with explicit keys. Every payload carries `schemaVersion`
(currently `2`); a reader rejects any other value.

### `getSecurityStatus` reply

| Key | Type | Meaning |
|---|---|---|
| `schemaVersion` | int | `2` |
| `root` | string | `detected`, `notDetected` or `unknown` |
| `rootSignals` | list of string | reason codes that fired. **Non-empty exactly when `root` is `detected`.** |
| `screenRecording` | string | `detected` (a recording is in progress), `notDetected` or `unknown` |
| `windowProtection` | string | `active` (the window is hidden from capture right now), `inactive` or `unknown`. Reported from the real window state, not from what the app asked for. |

Root reason codes: `su_binary`, `magisk_artifacts`, `root_manager_package`,
`which_su` (strong); `test_keys`, `debuggable_build` (weak). `debuggable_build` means
`Build.TYPE` is `userdebug` or `eng`; the `ro.debuggable` / `ro.secure` properties are
not used because an app cannot read them (see the device notes below).

`root` is `unknown` only when **every** check was inconclusive (none could run, or
there were none); a check that throws or times out is inconclusive and does not
affect the others. One flaky optional check therefore never makes a device
unverifiable on its own. A code the app does
not know is treated as a strong signal, never dropped, so Kotlin may add checks
without a Dart release. A payload that contradicts itself (detected without a
signal, signals without detected) is rejected, and the app then treats the
status as unknown.

### Screen recording event

`{ schemaVersion, screenRecording }`, with `screenRecording` as above.

### `startPayment` arguments

| Key | Type | Meaning |
|---|---|---|
| `schemaVersion` | int | `2` |
| `paymentId` | string | the bill being paid |
| `attemptId` | string | a fresh, non-empty processing identity for this execution, distinct from the bill |
| `amountMinor` | int | total in minor units; must be greater than 0 |
| `currency` | string | ISO 4217 code, e.g. `USD` |

No user-facing text and no merchant data crosses the channel. The notification
text is native resources (flavor `app_name` via `resValue`).

### `cancelPayment` arguments

`{ schemaVersion: 2, attemptId }`. The ID is required and non-empty; missing or malformed arguments are `INVALID_ARGS`. A valid ID that is not running is a successful no-op.

### `requestNotificationPermission` reply

A string: `granted`, `denied`, or `notRequired` (below API 33). It never fails: with no Activity to
show the prompt, or if anything goes wrong, the answer is `denied`. **Denial never stops a
payment**: the foreground service runs without its notification being shown, and Dart still
receives the progress. The use case calls repository preparation first, which asks through the data source, then makes a fresh security read before `startPayment`. It ignores the permission
answer; the system decides whether a prompt appears (it stops showing one after repeated denials).

### Payment progress event

`state` is one of the following, and each state carries only its own fields.

| `state` | Extra keys |
|---|---|
| `idle` | none (nothing running, nothing finished) |
| `running` | `paymentId`, `attemptId` (strings), `percent` (int, 0 to 100) |
| `succeeded` | `paymentId`, `attemptId`, `transactionId` (string), `amountMinor` (int), `currency` (string), `completedAtMillis` (int, epoch milliseconds) |
| `failed` | `paymentId`, `attemptId`, `errorCode`: `declined` or `processing_failed`. An unknown code is shown as a processing failure. |
| `cancelled` | `paymentId`, `attemptId` (strings) |

## Behaviour both sides must honour

These are what the contract test suites check; the fakes and the native
implementations must agree.

- **Replay on listen.** Both event channels emit the *current* value as soon as
  they are listened to (`idle` before any payment), then each change. Every
  listener gets that replay. A native `StreamHandler` does this in `onListen`.
- **Sticky terminal states.** `succeeded`, `failed` and `cancelled` stay current
  until the next `startPayment`.
- **One payment at a time.** `startPayment` while one runs fails with
  `ALREADY_RUNNING` and does not disturb the running payment.
- **`startPayment` returns on acceptance**, not on completion. Progress follows
  on the event channel.
- **`INVALID_ARGS`** for an amount that is not positive.
- **A start is a claim.** `startPayment` first claims the payment in a process-wide
  store with one atomic step, then asks the system to start the service; two starts
  that race cannot both get through. If the system refuses the service
  (`START_NOT_ALLOWED`, typically because the app is not in the foreground), the
  claim is given back, so the next try is not refused as `ALREADY_RUNNING` for a
  payment that never ran. A service that is started for a payment that is no longer
  the running one (a duplicate, or one cancelled before the service arrived) does
  nothing.
- **Attempt isolation.** All non-idle payment events identify both the bill and its attempt. A late progress, finish, rollback, timeout or cancel from an old attempt cannot affect a retry of the same bill. Schema v2 requires these fields; Dart and Kotlin ship together. This local execution identity is not a durable backend idempotency key.
- **Cancel is idempotent and scoped.** With nothing running or with a stale `attemptId` it is a no-op; otherwise the state becomes `cancelled`. The notification PendingIntent has distinct data for each attempt, and carries that attempt ID.
- **Cancel is one call, wherever it comes from.** From the app (`cancelPayment`) and
  from the notification's Cancel action it is the same store transition. The
  notification action is an immutable `PendingIntent.getBroadcast` to a **non-exported**
  receiver, so it does not depend on the service being alive and is not a service
  start; the service sees the payment leave `running` and winds down within one step.
  Of a cancel and a finish that race, the first wins.
- **The service.** A foreground service of type `shortService`, declared alone (the
  system ignores that type if it is combined with another): a payment is short,
  user-initiated and must finish. It has a 3 minute limit (API 34+), after which
  `onTimeout` (both overloads on Android 15) fails the payment as
  `processing_failed` and stops. `START_NOT_STICKY`: a payment never restarts by
  itself. It goes foreground first thing in `onStartCommand`, and on destroy fails
  only the attempt it ran itself. A new attempt retires and joins an old worker before running; duplicate delivery updates the latest startId without restarting work. Superseded workers cannot remove the replacement notification or stop its service.
- **The notification** is generic (no amount, no merchant), private on the lock
  screen, on a low-importance channel, throttled to two updates a second with the
  latest value always posted. A finished payment leaves "Payment complete" or
  "Payment failed" on screen, dismissible and removed when tapped; only a cancel
  removes the notification.
- **Notification permission** (API 33+) is requested through `requestNotificationPermission`,
  in repository preparation before the final domain security read, with no timeout on the prompt. A screen change or disposal invalidates pending confirmation before it can start processing.
  **Denial never stops a payment**: the service runs, nothing is shown, and Dart still
  receives the progress.
- **What survives what.** The state lives in memory in the process. The service and
  the state survive the app being backgrounded and the task being swiped away (the
  engine is destroyed, the process is not): a new engine is replayed the current state.
  A **killed process** (force-stop, out of memory) loses an in-flight payment: nothing
  restarts, and the app comes back with nothing running, so the payment is neither
  confirmed nor failed. That is acceptable only because the simulation moves no money
  and has no server; a real payment needs an idempotency key and reconciliation on
  launch (see `docs/ai/AI_INSIGHT_REPORT.md`, "Payments in production").
- **Secure window is reference counted.** The flag is set on the first enable
  and cleared when every enable has been balanced by a disable. A failed enable
  changes nothing.
- **`windowProtection` tells the truth.** `getSecurityStatus` reports `active`
  while the flag is set and `inactive` otherwise. The app blocks payment unless
  it is `active` (fail-closed), so a device that cannot protect its window never
  pays.
- **Threading.** Replies and event emissions happen on the platform main thread,
  exactly once per call; blocking work runs off it. The root checks run on
  `Dispatchers.IO`, concurrently, each capped at 2 s; everything that touches the
  `Window` stays on main.
- **Listeners are released.** Register system callbacks in `onListen`, unregister
  them in `onCancel`, and tolerate `onListen` being called again.
- **One native listener.** The Android `EventChannel` keeps a single active sink: a
  second `listen` replaces the first (the embedding calls `onCancel(null)` on the
  old one), and a `cancel` then cancels whichever sink is active. The Dart side
  therefore opens exactly one native subscription however many Dart listeners
  there are, closes it after the last, and replays the latest state to each
  listener, never one from before it reopened.
- **No Activity.** `enableSecureWindow` fails with `UNAVAILABLE` and counts
  nothing; `getSecurityStatus` still answers, with `windowProtection: inactive` and
  `screenRecording: unknown`.
- **Config changes.** The enable count outlives the window: a re-created Activity
  gets `FLAG_SECURE` again before anyone asks. The recording callback is released
  with the Activity and registered again on the new one; nothing is emitted for the
  gap, and after it only a real change is.
- **Recording needs the platform.** From API 35 the state comes from
  `WindowManager.addScreenRecordingCallback` (`DETECT_SCREEN_RECORDING`, requested
  from API 35 only). Below 35 it is always `unknown`, never `notDetected`: there is
  no official API, the API 34 screenshot callback detects screenshots, not
  recordings, and a `DisplayManager` heuristic would also flag casting.
- **Calls time out.** A call that is never answered fails on the Dart side as
  `UNAVAILABLE` after 5 s, so a hang is an explicit failure, not an endless wait.
- **Errors carry no detail.** An unexpected native exception is answered as
  `INTERNAL` with a fixed message, never the exception's text, which could hold a
  path.
- **No native side.** On iOS, desktop and plain `flutter test` there is no handler:
  calls fail as unsupported and the device reads as unverifiable. Flutter's own
  `EventChannel` swallows the failed listen, so the recording stream stays silent.

## Dart side

| Piece | File |
|---|---|
| Names, keys, codes (mirror of `Channels.kt`) | `lib/core/platform/channel_contract.dart` |
| Security channel source (shared native listener, timeouts) | `features/security/data/datasources/channel_security_platform_data_source.dart` |
| Native side of the security channels played in Dart, for the contract suite | `test/features/security/helpers/native_security_simulator.dart` |
| Validating payload reader | `lib/core/platform/wire_reader.dart` |
| Data-source contracts | `features/security/data/datasources/security_platform_data_source.dart`, `features/payment/data/datasources/payment_platform_data_source.dart` |
| Wire DTOs (`fromMap`/`toMap`) | `features/*/data/dtos/` |
| Contract test suites | `test/features/*/data/*_platform_data_source_contract.dart` |

The channel-based data sources receive their `MethodChannel`/`EventChannel`
through the constructor, catch `PlatformException` and `MissingPluginException`,
and throw the typed `DataSourceException`s from `lib/core/error/`. Nothing above
the data layer changes when they replace the fakes.

## Verified on a device (security)

Pixel_9 emulator, API 36 (`google_apis_playstore`, arm64, `user` build,
`release-keys`), retail debug build, 2026-10-15. Screenshots and window state were
read with `adb`; the app's own view comes from the debug log of `SecurityPlugin`.

| Check | Result |
|---|---|
| Root signals the app reports | none: `root=notDetected signals=[] inconclusive=[]`, so all six checks ran and none fired |
| `FLAG_SECURE` and screenshots | `adb exec-out screencap` of the payment screen is one flat black colour; the launcher, as a control, has 31,000+ colours. `dumpsys window` lists `SECURE` in the `MainActivity` window flags |
| Recents thumbnail | the app's card in Overview is black |
| `windowProtection` | `active` in the first status read after launch, so the wait for the window (settle before check) works |
| Rotation and Activity re-creation ("Don't keep activities") | `FLAG_SECURE` still present, screenshot still black, no crash or "Reply already submitted" in the log |
| `DETECT_SCREEN_RECORDING` | granted at install (a normal permission) |
| Source swap Real → Simulated → Real | `SECURE` stays present and the screenshot stays black in both modes: the window always goes through the real source, the simulation only replaces readings. (An earlier build, where the simulation owned a window of its own, left the window unprotected in Simulated mode; that was changed.) |
| Simulated scenario "screen protection unavailable" | the page shows "Screen protection could not be turned on, so payment is paused" with "Check again", while `SECURE` stays present and the screenshot stays black |
| `adb shell screenrecord` | **not detected**: the recording readout stayed `notDetected` for the whole recording. It is not a MediaProjection capture, which is what the API 35 callback reports |
| Screen record quick-settings tile (MediaProjection) | not run on the emulator; run on the phone, see [below](#recording-callback-while-the-window-is-secure-defense-in-depth) |

Notes from the device:

- `getprop ro.debuggable` and `ro.secure` print nothing from the app's SELinux domain
  (checked with `run-as`, a close but not identical domain), so a `getprop`-based
  check could never run. The check reads `Build.TYPE` instead.
- `which su` runs from the app and is conclusive (exit 1, nothing found).
  `/data/adb` is not readable by an app, so the Magisk path check says little on a
  modern Android; it is kept for older layouts.
- Other emulator images were not available to check. From memory, not verified here:
  a `google_apis` (non-Play) userdebug image has `test-keys` and `userdebug`, both
  weak and allowed by default, and often ships `su`, which is strong and blocks.

### Recording callback while the window is secure (defense in depth)

Whether `addScreenRecordingCallback` still reports the app as visible in a recording
when the window carries `FLAG_SECURE` was checked on a phone on 2026-10-16 (`M4-5`).
On Android 16 (ZTE RedMagic 10 Pro, the phone's own screen recorder) the callback did
not fire: nothing changed in the app and no recording block appeared. The finding is
**defense in depth**.

- **Why the callback stays silent, a hypothesis and not proven:** the saved recording
  shows the app area black (`M4-4`), so the window was left out of the capture, and the
  silent callback is consistent with that: the app is not "visible in the recording" and
  the callback has nothing to report. This run cannot rule out another explanation, that
  this maker's recorder is not reported to the callback at all; telling the two apart
  would need a recording of a window without `FLAG_SECURE` that the callback does or does
  not report, and none was made on the phone.
- **What stays:** the detection, as an extra layer. `FLAG_SECURE` is the primary control.
  The recording block is not to be relied on.
- **Device-verified:** the saved screen recording was checked on the phone and the app area
  is black (`M4-4`), so `FLAG_SECURE` keeps the page out of a recording. Not noted: the
  panel's Screen recording readout during the recording.
- **Scope:** one phone, one recorder, Android 16.

## Verified on a device (payment)

Pixel_9 emulator, API 36 (`google_apis_playstore`, arm64, `user` build), retail
debug build and a release (R8) build, 2026-10-16. Everything below was driven and
read with `adb` (`dumpsys notification`, `dumpsys activity services`, screenshots of
the shade, taps by coordinates); what needs a person is in `docs/MANUAL_QA.md`.

| Check | Result |
|---|---|
| Service type | `dumpsys activity services`: `isForeground=true`, `types=0x00000800` (`shortService`), `isShortFgs=true`, `timeout=+2m57s`, `stopIfKilled=true` (not sticky). The same on the release build |
| Notification record | channel `payment_progress`, importance 2 (low), `category=progress`, `vis=PRIVATE`, flags `ONGOING_EVENT\|ONLY_ALERT_ONCE\|FOREGROUND_SERVICE`, a content intent (`startActivity`), one action "Cancel" whose `PendingIntent` is a **broadcast** |
| Live progress | the notification goes 0, 5, 10, 15, 25, 30 ... 100 at about one update every 0.5 s while the processor ticks every 0.4 s: the throttle coalesces, never more than two a second, and the last value is posted. Then "Payment complete" |
| Permission prompt | the first payment shows "Allow Retail Shop to send you notifications?" **before** the service starts |
| Permission denied | the payment still runs (foreground service, receipt, native transaction id) and **no notification** is posted |
| Final notification | after a success: "Payment complete", flags `ONLY_ALERT_ONCE\|AUTO_CANCEL` (not ongoing, dismissible, removed when tapped). Posted **after** `stopForeground(DETACH)`: posting it before left no `AUTO_CANCEL`, because the system keeps the foreground notification non-cancellable |
| Shade | the card sits in the **Silent** section, shows "Processing your payment", a progress bar and, expanded, a **Cancel** action |
| Cancel from the notification | tapping it removes the notification and stops the service within 0.4 s, and the app shows "Payment cancelled" |
| Cancel from the app | the same result |
| Backgrounded mid-payment | Home with the payment at 50%: the service stays foreground, the notification keeps updating, and the app shows the receipt on return |
| Task swiped away mid-payment | the process keeps its pid, the service carries on (55% to 75% with no app), and the reopened app (a new engine) shows the receipt |
| Process death | `am force-stop` mid-payment: notification and service gone; the relaunched app starts from a fresh review screen (the interrupted payment is neither confirmed nor failed, as documented); a new payment then runs and completes |
| Release build (R8) | a payment runs on a non-debuggable release build: foreground `shortService`, no crash; the manifest components are kept by name |
| No SIMULATED badge | with both sources real, the badge is not shown |

Not reproducible by hand, covered by JVM tests only: `ForegroundServiceStartNotAllowedException`
(it needs a start from the background), the 3 minute `onTimeout`, and the "Payment failed"
notification (the native simulation always succeeds).

**Not tested on a phone** (`docs/MANUAL_QA.md`, M5): the permission prompt, the look of the shade in
detail, the lock screen, swiping the app away, other API levels (the type is masked to nothing below
API 34 by `ServiceCompat`, which was read from its bytecode, not run), battery saver and Doze. What the
phone did show is under [Verified on a phone](#verified-on-a-phone-2026-10-16).

## Verified on a phone (2026-10-16)

ZTE RedMagic 10 Pro, Android 16 (API 36). The build was the Retail profile APK built at 12:34, copied to
the phone by hand: the code of `90862ac`, so **before** the last three code commits (`086992c`, `d50d208`,
`d572cff`); it already had schema v2 and the attempt ids. The run was not repeated on the final code. The
phone was observed by a person, not driven with `adb`; items marked *not tested* were not reported.

| Check | Result |
|---|---|
| Root check | the device was verified, Pay was enabled and payments went through |
| `FLAG_SECURE` | screenshots are blocked by the system; the app is blacked out in Recents |
| Screen recording (the phone's own recorder) | no recording block appeared: **defense in depth**, see [above](#recording-callback-while-the-window-is-secure-defense-in-depth) |
| Saved screen recording | the app area is black: `FLAG_SECURE` is device-verified against recording |
| Live progress notification | seen |
| Cancel | works; which path (the notification's or the app's) was not recorded each time |
| Home during a payment, then back | the progress was shown |
| Both brands, demo panel scenarios | look right and work; no bug noticed |
| Frame rate | 120 FPS on the performance overlay, no visible drops: qualitative, the frame-timing harness was not run |
| **Not tested** | the notification permission prompt, which Cancel path each time, Utility's 1.6 s scan speed, and the other items marked so in [`MANUAL_QA.md`](MANUAL_QA.md) |

## Validation after the attempt-isolation fix

The v2 schema and service coordinator were verified by Dart contract tests, JVM tests, the emulator device suites and debug/release APK builds for both brands. The older device observations above describe the v1 implementation. The phone run (2026-10-16) used a build that already had the v2 schema, but it did not test the rapid cancel/retry and stale-notification scenarios (see the review-fix table in [Manual QA](MANUAL_QA.md)); those rest on the automated suites. The only phone evidence for 120 Hz is the qualitative observation above.
