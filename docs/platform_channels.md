# Platform channel contract

Single source of truth for the Dart ↔ Kotlin bridge. Keep it in sync with
`lib/core/platform/channel_contract.dart` (Dart) and
`android/app/src/main/kotlin/.../bridge/Channels.kt` (Kotlin).
Update this file in the same change that alters the contract.

**Status: draft v1, Dart side only.** The Dart constants, the DTO parsing and the
contract test suites exist and are tested against fakes. The Kotlin side
(`bridge/Channels.kt`, the plugins, the foreground service) is written in the
native milestones and must match this document.

All names start with `com.hypertenant.secure_payment_portal` (written `…` below).
They never depend on the `applicationId`, which differs per flavor.

## Channels

| Channel | Type | Method / event | Args | Returns / emits | Error codes | Min API notes |
|---|---|---|---|---|---|---|
| `…/security` | Method | `getSecurityStatus` | none | map: `schemaVersion`, `root`, `rootSignals`, `screenRecording` | `INTERNAL`, `UNAVAILABLE` | Root checks work on every supported API. Recording state is real on API 35+ and `unknown` below. |
| `…/security` | Method | `enableSecureWindow` | none | `null` | `UNAVAILABLE` (no Activity) | `FLAG_SECURE`, any API. Reference counted. |
| `…/security` | Method | `disableSecureWindow` | none | `null` | `UNAVAILABLE` | Balances `enableSecureWindow`; an extra call is ignored. |
| `…/security/screen_recording` | Event | recording changes | none | map: `schemaVersion`, `screenRecording` | — | API 35+ detection callback; below that it emits `unknown`. |
| `…/payment` | Method | `startPayment` | map: `schemaVersion`, `paymentId`, `amountMinor`, `currency` | `null` once processing was **accepted** | `ALREADY_RUNNING`, `START_NOT_ALLOWED`, `INVALID_ARGS` | Foreground service started from a user action while the app is visible. |
| `…/payment` | Method | `cancelPayment` | none | `null` | `INTERNAL` | With nothing running it does nothing. |
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

Root reason codes: `su_binary`, `magisk_artifacts`, `root_manager_package`,
`which_su` (strong); `test_keys`, `debuggable_build` (weak). A code the app does
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
  and cleared when every enable has been balanced by a disable.
- **Threading.** Replies and event emissions happen on the platform main thread,
  exactly once per call; blocking work runs off it.
- **Listeners are released.** Register system callbacks in `onListen`, unregister
  them in `onCancel`, and tolerate `onListen` being called again.

## Dart side

| Piece | File |
|---|---|
| Names, keys, codes (mirror of `Channels.kt`) | `lib/core/platform/channel_contract.dart` |
| Validating payload reader | `lib/core/platform/wire_reader.dart` |
| Data-source contracts | `features/security/data/datasources/security_platform_data_source.dart`, `features/payment/data/datasources/payment_platform_data_source.dart` |
| Wire DTOs (`fromMap`/`toMap`) | `features/*/data/dtos/` |
| Contract test suites | `test/features/*/data/*_platform_data_source_contract.dart` |

The channel-based data sources receive their `MethodChannel`/`EventChannel`
through the constructor, catch `PlatformException` and `MissingPluginException`,
and throw the typed `DataSourceException`s from `lib/core/error/`. Nothing above
the data layer changes when they replace the fakes.
