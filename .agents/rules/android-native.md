---
trigger: model_decision
description: "Android native layer (Kotlin) and the Flutter platform bridge. Apply when editing anything under android/, Gradle files, AndroidManifest.xml, MethodChannel/EventChannel code on either side, root/screen-recording detection, FLAG_SECURE, notifications or the payment Foreground Service."
---

# Android native integration ("Security Guard")

The reviewers grade **Android depth**: service lifecycle, channel thread-safety and modern API compliance (targetSdk 36, minSdk 24). Write Kotlin the way a senior Android engineer would. This is not "glue code in MainActivity".

## 1. Structure

```
android/app/src/main/kotlin/com/hypertenant/secure_payment_portal/
├── MainActivity.kt                 # ONLY: flutterEngine.plugins.add(...) for each module
├── bridge/
│   ├── Channels.kt                 # channel names, method names, arg keys, error codes (mirror of Dart)
│   └── SafeResult.kt               # MethodChannel.Result wrapper: main-thread, reply-once
├── security/
│   ├── SecurityPlugin.kt           # FlutterPlugin + ActivityAware; MethodChannel + EventChannel
│   ├── RootDetector.kt             # composes List<RootCheck>; pure logic, unit-testable
│   ├── checks/                     # one class per heuristic (SuBinaryCheck, TestKeysCheck, …)
│   ├── ScreenRecordingMonitor.kt   # API-level-aware detection, emits tri-state
│   └── SecureWindowController.kt   # FLAG_SECURE with reference counting
└── payment/
    ├── PaymentServicePlugin.kt     # start/cancel commands + progress EventChannel
    ├── PaymentProcessingService.kt # the Foreground Service
    ├── PaymentNotificationFactory.kt
    └── PaymentProgressStore.kt     # process-wide StateFlow<PaymentProgress> (service → plugin)
```

- Each native module is an **in-app `FlutterPlugin`** (plus `ActivityAware` when it needs the Activity) and is registered in `MainActivity.configureFlutterEngine` with `flutterEngine.plugins.add(...)`. This gives correct attach/detach callbacks, including `onDetachedFromActivityForConfigChanges` and `onReattachedToActivityForConfigChanges`. Never keep a strong `Activity` reference beyond `onDetachedFromActivity`.
- Single responsibility: plugins translate channel calls into Kotlin calls and nothing more. Logic lives in plain classes that take their dependencies (`Context`, file checker, props reader) through constructors, so JVM unit tests can cover them.

## 2. Channel contract (both sides)

- Channel names are stable and brand-agnostic: `com.hypertenant.secure_payment_portal/<module>`. Don't derive them from `applicationId`, which changes per flavor.
- Use `MethodChannel` for commands and queries, and `EventChannel` for streams (screen-recording state, payment progress). Don't poll from Dart.
- Every method name, argument key and error code exists **once** on each side: `bridge/Channels.kt` and `lib/core/platform/`. When you change the contract, update both files and the table in `docs/platform_channels.md` in the same change.
- Payloads are flat maps of primitives with explicit keys and versionable shape. The Dart data source parses them into DTOs with validation. Raw maps never reach the domain layer.
- Unknown method → `result.notImplemented()`. Bad arguments → `result.error(INVALID_ARGS, …)`. Never crash the engine.

## 3. Threading and reply safety (critical)

- Handlers are invoked on the **platform main thread**. Don't block it: file system checks, `Runtime.exec` and package queries run in `withContext(Dispatchers.IO)`.
- Reply (`success`, `error`, `notImplemented`) and `EventSink` emissions happen on the **main thread**, **exactly once** per call. Wrap `Result` in `SafeResult`, which posts to `Dispatchers.Main.immediate` and ignores or logs a second reply instead of throwing "Reply already submitted".
- Coroutines run in a scope owned by the plugin or service: `CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)`, cancelled in `onDetachedFromEngine` or `onDestroy`. Never use `GlobalScope` or `runBlocking` on the main thread.
- `EventChannel.StreamHandler`: register system callbacks in `onListen` and unregister them in `onCancel`. Null out the sink. Tolerate `onListen` being called again after `onCancel`.
- A background `TaskQueue` (`binaryMessenger.makeBackgroundTaskQueue()`) is acceptable for pure, UI-free handlers. Anything that touches `Window` or `Activity` stays on main.

## 4. Feature specs

### 4.1 Root detection
- Combine independent heuristics, each a `RootCheck` returning a named signal:
  - `su` binaries in the known paths
  - Magisk artifacts
  - `Build.TAGS` containing `test-keys`
  - known root-manager packages — Android 11+ package visibility requires `<queries>` entries in the manifest
  - `ro.debuggable` / `ro.secure` props
  - an optional `which su` with a timeout
- Return **which** signals fired (`List<String>` of reason codes), not just a boolean. Domain decides the policy.
- Document honestly in KDoc: client-side root checks are heuristics that tools like Magisk DenyList/Zygisk can bypass. Production would add server-verified **Play Integrity API**. Don't present heuristics as tamper-proof.

### 4.2 Screen recording / capture detection
- **API 35+:** `WindowManager.addScreenRecordingCallback(executor, consumer)` + `<uses-permission android:name="android.permission.DETECT_SCREEN_RECORDING"/>`. Map `SCREEN_RECORDING_STATE_VISIBLE` / `NOT_VISIBLE`. Remove the callback when listening stops or the Activity detaches.
- **API 34 (optional):** `Activity.registerScreenCaptureCallback` + `DETECT_SCREEN_CAPTURE` detects *screenshots*, not recording. Label it accordingly.
- **Below API 35:** there is no official API. You may use the `DisplayManager` heuristic (extra or presentation displays, which suggest casting or mirroring), but the result is `unknown` when nothing reliable is available. Don't return `notRecording` when you can't know.
- Stream changes over the EventChannel and also expose a one-shot `getSecurityStatus` query.

### 4.3 Window protection (FLAG_SECURE)
- Dart drives it. The payment page is wrapped in a `SecureScreen` widget (security feature, presentation layer) that calls `enableSecureWindow` when the route becomes visible and `disableSecureWindow` when it is popped or disposed. Use `RouteAware` with a `RouteObserver`, so pushing another route on top behaves correctly.
- Native side: `SecureWindowController` keeps a **reference count**, adding the flag on 0→1 and clearing it on 1→0. It always runs `window.addFlags/clearFlags(FLAG_SECURE)` on the UI thread and re-applies the flag after Activity re-attach (config change).
- Optional hardening: `setRecentsScreenshotEnabled(false)` (API 33+) while secure.

### 4.4 Foreground Service (payment processing simulation)
- Manifest: `<service android:name=".payment.PaymentProcessingService" android:exported="false" android:foregroundServiceType="…"/>`, `FOREGROUND_SERVICE`, the matching `FOREGROUND_SERVICE_<TYPE>` permission (API 34+) and `POST_NOTIFICATIONS`.
- Pick the type deliberately and justify it in KDoc. `shortService` fits a short, must-finish payment: no extra type permission, about a 3 minute limit, and you must handle `onTimeout`. `dataSync` is the alternative, with its own permission and Android 15 daily limits. Don't use `specialUse` without a reason.
- Start: `ContextCompat.startForegroundService` **only in response to a user action while the app is visible** (Android 12+ background-start restrictions). Catch `ForegroundServiceStartNotAllowedException` and map it to a channel error. Then call `ServiceCompat.startForeground(this, id, notification, type)` promptly in `onStartCommand`, passing the type only on API levels where it is defined.
- Notification:
  - Channel created once (API 26+), importance LOW.
  - `NotificationCompat` with `setOngoing(true)`, `setOnlyAlertOnce(true)`, `setProgress(max, current, indeterminate)` and `CATEGORY_PROGRESS`.
  - `setForegroundServiceBehavior(FOREGROUND_SERVICE_IMMEDIATE)`.
  - A content `PendingIntent` with `FLAG_IMMUTABLE`.
  - **Throttle** updates to at most about 2 per second; the system rate-limits them anyway.
- `POST_NOTIFICATIONS` (API 33+) is requested before starting, through the bridge. If it is denied, processing still works and Dart still receives progress.
- Lifecycle:
  - Return `START_NOT_STICKY`: a payment must never silently restart.
  - Ignore or reject a duplicate start while a payment is running (idempotent).
  - Work runs in a service-owned coroutine scope that is cancelled in `onDestroy`.
  - On finish, publish the terminal state, then call `ServiceCompat.stopForeground(this, STOP_FOREGROUND_REMOVE)` (or `DETACH` to leave a final "Payment complete" notification) and `stopSelf(startId)`.
  - Support cancel.
- Service → Dart: the service publishes to `PaymentProgressStore` (`StateFlow`). `PaymentServicePlugin` collects it while the EventChannel is listened to. The service never references `FlutterEngine` or `Activity`.

## 5. Gradle and compliance

- Kotlin DSL only. Add `androidx.core:core-ktx` and `org.jetbrains.kotlinx:kotlinx-coroutines-android` with explicit versions. Keep `compileSdk`/`targetSdk`/`minSdk` from the Flutter Gradle plugin unless there is a reason.
- Guard every API above minSdk with `Build.VERSION.SDK_INT` + `@RequiresApi`, and write the API level in a comment next to the call.
- No deprecated APIs where a replacement exists: `ServiceCompat.stopForeground`, `PendingIntent.FLAG_IMMUTABLE`, `NotificationCompat`, `ContextCompat`.
- Release builds must work with R8. Don't rely on reflection.
- Never branch on flavor in Kotlin. Brand-specific values (notification color, app name) come from `resValue`, flavor `res/` or Dart arguments.

## 6. Dart side of the bridge

- `features/<x>/data/datasources/<x>_platform_data_source.dart` receives a `MethodChannel`/`EventChannel` through its constructor, which makes it testable with `TestDefaultBinaryMessengerBinding`.
- It catches `PlatformException` → typed `Failure`, and `MissingPluginException` (iOS, tests) → `unknown`/unsupported state. It never throws past the repository.
- Event streams are exposed as domain streams (`Stream<ScreenRecordingState>`, `Stream<PaymentProgress>`), mapped once, and surfaced to the UI through `StreamProvider`s in the feature's `di/`. Presentation never imports `flutter/services.dart` for channels.
- Do not build a repository's event stream with `async*` while it waits on a quiet inner stream: cancelling an `async*` stream only takes effect at its next `yield`, so the native listener stays registered until the next event. Use a `StreamController` whose `onCancel` cancels the inner subscription.
- Riverpod 3 filters `StreamProvider` events with `==`. Make event entities `Equatable`, so that dropping identical consecutive states is intended rather than accidental.
- Channel providers (`MethodChannel`/`EventChannel` instances) are plain `Provider`s, so tests can override them.

## 7. Self-check before finishing native work

- [ ] Every channel call replies exactly once, on main; no blocking work on main.
- [ ] Callbacks, scopes and sinks are released on detach, cancel or destroy; no Activity leaks across config changes.
- [ ] Every API > 24 is guarded and annotated; permissions are declared with the correct API scope.
- [ ] The FGS type is declared, the permission added, the start is user-initiated, the stop path is correct, and the timeout is handled.
- [ ] `Channels.kt`, `lib/core/platform/` and `docs/platform_channels.md` are in sync.
- [ ] `flutter build apk --debug --flavor <each>` succeeds.
