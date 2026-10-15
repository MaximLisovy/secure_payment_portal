# Platform channel contract

Single source of truth for the Dart ↔ Kotlin bridge. Keep it in sync with
`lib/core/platform/channel_contract.dart` (Dart) and
`android/app/src/main/kotlin/.../bridge/Channels.kt` (Kotlin).
Update this file in the same change that alters the contract.

**Status.**

- **Security (`…/security`, `…/security/screen_recording`): draft v1, implemented.**
  Kotlin (`SecurityPlugin`) and Dart (`ChannelSecurityPlatformDataSource`) both
  exist and were checked on a Pixel_9 emulator (API 36), as listed under
  [Verified on a device](#verified-on-a-device-security). It stays **draft** until
  one manual check is done and written down: what the recording callback does
  while the window is secure (**pending manual verification**, below). It becomes
  final then, in a small docs commit.
- **Payment (`…/payment`, `…/payment/progress`): draft v1.** The Dart constants, the
  DTO parsing and the contract suite exist and run against the fake. The Kotlin
  foreground service is written in the payment milestone and must match this
  document.

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
| `…/payment` | Method | `startPayment` | map: `schemaVersion`, `paymentId`, `amountMinor`, `currency` | `null` once processing was **accepted** | `ALREADY_RUNNING`, `START_NOT_ALLOWED`, `INVALID_ARGS` | Foreground service started from a user action while the app is visible. |
| `…/payment` | Method | `cancelPayment` | none | `null` | `INTERNAL` | With nothing running it does nothing. |
| `…/payment` | Method | `requestNotificationPermission` | none | string: `granted`, `denied` or `notRequired` | — (never fails) | Runtime permission from API 33; `notRequired` below. Called by the Dart data source before `startPayment`. |
| `…/payment/progress` | Event | payment progress | none | map: `schemaVersion`, `state`, plus the fields of that state | — | Fed by the service's process-wide state. |

Unknown method → `notImplemented`. Bad arguments → `INVALID_ARGS`. The engine never crashes.

## Payloads

Flat maps of primitives with explicit keys. Every payload carries `schemaVersion`
(currently `1`); a reader rejects any other value.

### `getSecurityStatus` reply

| Key | Type | Meaning |
|---|---|---|
| `schemaVersion` | int | `1` |
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
| `schemaVersion` | int | `1` |
| `paymentId` | string | the bill being paid |
| `amountMinor` | int | total in minor units; must be greater than 0 |
| `currency` | string | ISO 4217 code, e.g. `USD` |

No user-facing text and no merchant data crosses the channel. The notification
text is native resources (flavor `app_name` via `resValue`).

### `requestNotificationPermission` reply

A string: `granted`, `denied`, or `notRequired` (below API 33). It never fails: with no Activity to
show the prompt, or if anything goes wrong, the answer is `denied`. **Denial never stops a
payment**: the foreground service runs without its notification being shown, and Dart still
receives the progress. The Dart data source calls it before every `startPayment` and ignores the
answer; the system decides whether a prompt appears (it stops showing one after repeated denials).

### Payment progress event

`state` is one of the following, and each state carries only its own fields.

| `state` | Extra keys |
|---|---|
| `idle` | none (nothing running, nothing finished) |
| `running` | `paymentId` (string), `percent` (int, 0 to 100) |
| `succeeded` | `paymentId`, `transactionId` (string), `amountMinor` (int), `currency` (string), `completedAtMillis` (int, epoch milliseconds) |
| `failed` | `errorCode`: `declined` or `processing_failed`. An unknown code is shown as a processing failure. |
| `cancelled` | none |

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
- **Cancel is idempotent.** With nothing running it is a no-op; otherwise the
  state becomes `cancelled`.
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
| Screen record quick-settings tile (MediaProjection) | **pending manual verification**, see below |

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

### Recording callback while the window is secure (pending manual verification)

Whether `addScreenRecordingCallback` still reports the app as visible in a recording
when the window carries `FLAG_SECURE` (the recording then shows black) is **not yet
known**: the check is a manual one with the Screen record quick-settings tile, to be
done by the developer. Until it is, the detection stays as implemented and nothing
below is claimed. The finding will be written here as one of:

- **verified**: the callback fires with `FLAG_SECURE` on, so the recording block
  works as a second line; or
- **defense in depth**: the callback never fires for a secure window; the block is
  then redundant with `FLAG_SECURE`, which already blacks the recording out. The
  detection is kept regardless.
