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
│   ├── SecurityPlugin.kt           # FlutterPlugin + ActivityAware: wires lifecycles, nothing else
│   ├── SecurityMethodHandler.kt    # the method channel: reply once, on main, errors → INTERNAL
│   ├── RecordingStreamHandler.kt   # the event channel: replay on listen, release on cancel
│   ├── SecurityStatusPayload.kt    # the wire maps; pure
│   ├── RootDetector.kt             # runs List<RootCheck> concurrently and combines; pure logic
│   ├── checks/                     # one class per heuristic (SuBinaryCheck, TestKeysCheck, …)
│   ├── probes/                     # ports + Android adapters: files, packages, commands, Build
│   ├── ScreenRecordingMonitor.kt   # joins the Dart listener and the Activity lifecycle
│   ├── ScreenRecordingSource.kt    # port: API 35 WindowManager source, or "unknown" below 35
│   ├── SecureWindowController.kt   # FLAG_SECURE with reference counting; pure logic
│   └── SecureWindowTarget.kt       # port + the Activity Window adapter
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
- The embedding keeps **one active sink per EventChannel**: `onListen` swaps in the new sink and calls `onCancel(null)` on the old one, and `onCancel` cancels whichever sink is active (or fails with "No active stream to cancel"). Dart must therefore hold one native subscription for any number of Dart listeners (see section 6).
- A background `TaskQueue` (`binaryMessenger.makeBackgroundTaskQueue()`) is acceptable for pure, UI-free handlers. Anything that touches `Window` or `Activity` stays on main.

## 4. Feature specs

### 4.1 Root detection
- Combine independent heuristics, each a `RootCheck` returning a named signal:
  - `su` binaries in the known paths
  - Magisk artifacts
  - `Build.TAGS` containing `test-keys`
  - known root-manager packages — Android 11+ package visibility requires `<queries>` entries in the manifest, kept equal to `RootManagerPackages` by a unit test
  - `Build.TYPE` of `userdebug` or `eng` (weak). **Not** `ro.debuggable` / `ro.secure` through `getprop`: an app cannot read them (SELinux), so that check could never run (found on an API 36 device)
  - `which su` with a timeout
- Return **which** signals fired (`List<String>` of reason codes), not just a boolean. Domain decides the policy.
- Each check answers `Clear`, `Fired` or `Inconclusive`. `unknown` only when **every** check is inconclusive; a check that throws or times out is inconclusive and never takes the others down. Cancelling the caller still cancels the detection, and a cancellation raised *inside* a check (its own `withTimeout`) is that check failing.
- `Process.waitFor(long, TimeUnit)`, `isAlive` and `destroyForcibly` are API 26 and minSdk is 24: poll `exitValue()` and end the process with `destroy()`.
- Document honestly in KDoc: client-side root checks are heuristics that tools like Magisk DenyList/Zygisk can bypass. Production would add server-verified **Play Integrity API**. Don't present heuristics as tamper-proof.

### 4.2 Screen recording / capture detection
- **API 35+:** `WindowManager.addScreenRecordingCallback(executor, consumer)` on the **Activity's** `WindowManager`, with `<uses-permission android:name="android.permission.DETECT_SCREEN_RECORDING" android:minSdkVersion="35"/>` (a normal permission, granted at install). Map `SCREEN_RECORDING_STATE_VISIBLE` / `NOT_VISIBLE`. Use the main executor, so every callback is on main. Remove the callback when listening stops or the Activity detaches, and register again on the new Activity.
- **Below API 35: always `unknown`**, never `notRecording`. No `DisplayManager` heuristic (it would also flag casting and mirroring) and no API 34 screenshot callback (`registerScreenCaptureCallback` detects *screenshots*, not recordings, and the contract has no field for it).
- Only a MediaProjection capture is seen by the callback: `adb shell screenrecord` is not (checked on API 36).
- Stream changes over the EventChannel and also expose a one-shot `getSecurityStatus` query.

### 4.3 Window protection (FLAG_SECURE)
- Dart drives it. The payment page is wrapped in a `SecureScreen` widget (security feature, presentation layer). It protects from its first build until it is **disposed**, not until its route is covered. A `RouteAware` that releases on `didPushNext` or `didPop` leaves the sensitive page visible but unprotected for the whole transition animation (about 300 ms), because the outgoing page is still on screen while the new route slides in. Protection that outlives visibility costs nothing; the opposite leaks.
- A single app-scoped notifier (`secureWindowProvider`) owns the window: screens `acquire` and `release` it, and the platform is asked only for the first acquire and the last release. The status the policy reads (`windowProtection`) comes from the real window state, and the policy blocks payment unless it is `active`.
- Native side: `SecureWindowController` keeps a **reference count**, adding the flag on 0→1 and clearing it on 1→0. It runs `window.addFlags/clearFlags(FLAG_SECURE)` on the UI thread. The count outlives the window: `detach()` keeps it and `attach()` applies the flag to the new window at once. An enable with no window fails (`UNAVAILABLE`) and counts nothing. `protection()` reads the flag from the window itself, not from the count.
- `FLAG_SECURE` also hides the recents thumbnail on every API level (checked on API 36), so `setRecentsScreenshotEnabled(false)` is not used.
- **The window is real in every mode.** `secureWindowControllerProvider` always goes through the real channel source (`secureWindowPlatformDataSourceProvider`), whichever security source is selected. The simulation replaces *readings* (root, recording, the scenarios, and the `windowProtection` it reports) and never `FLAG_SECURE`, so a simulated build is as hard to capture as a real one. A simulated scenario may *report* that protection is unavailable without removing the flag (`SecurityScenarioControl.screenProtectionAvailable`). Where no real source is wired (a test that overrides it with null) the window calls fall back to the selected source.

### 4.4 Foreground Service (payment processing simulation)
- Manifest: `<service android:name=".payment.PaymentProcessingService" android:exported="false" android:foregroundServiceType="…"/>`, `FOREGROUND_SERVICE`, the matching `FOREGROUND_SERVICE_<TYPE>` permission (API 34+) and `POST_NOTIFICATIONS`.
- Pick the type deliberately and justify it in KDoc. `shortService` fits a short, must-finish payment: no extra type permission, about a 3 minute limit, and you must handle `onTimeout` (API 34 `onTimeout(int)`; on API 35 both overloads are called, so make it idempotent). **Declare it alone**: the system ignores `shortService` when it is combined with another type, so there is no `dataSync` fallback to add. `dataSync` is the alternative, with its own permission and Android 15 daily limits. Don't use `specialUse` without a reason.
- Start: `ContextCompat.startForegroundService` **only in response to a user action while the app is visible** (Android 12+ background-start restrictions). Catch `ForegroundServiceStartNotAllowedException` and map it to a channel error. Then call `ServiceCompat.startForeground(this, id, notification, type)` promptly in `onStartCommand` and keep it to that: the compat call passes the type through on API 34+ and masks it to `0xFF` on 29 to 33 (read from its bytecode), so no `SDK_INT` branch of ours is needed. Claim the payment in the store **before** starting the service and give the claim back if the start is refused, so a refused start does not leave the store saying "running".
- Notification:
  - Channel created once (API 26+), importance LOW.
  - `NotificationCompat` with `setOngoing(true)`, `setOnlyAlertOnce(true)`, `setProgress(max, current, indeterminate)` and `CATEGORY_PROGRESS`.
  - `setForegroundServiceBehavior(FOREGROUND_SERVICE_IMMEDIATE)`.
  - A content `PendingIntent` with `FLAG_IMMUTABLE`.
  - **Throttle** updates to at most about 2 per second; the system rate-limits them anyway.
  - **The Cancel action is a `PendingIntent.getBroadcast` (`FLAG_IMMUTABLE`) to a non-exported `BroadcastReceiver`** that calls `store.cancelIfRunning()`. It does not depend on the service being alive and is not a service start, so no background-start restriction applies. Keep the manifest guard test in step when a component is added.
- `POST_NOTIFICATIONS` (API 33+) is requested before starting, through its own bridge method (`requestNotificationPermission`, called by the Dart data source before `startPayment`, with no timeout on the prompt). If it is denied, processing still works and Dart still receives progress.
- Lifecycle:
  - Return `START_NOT_STICKY`: a payment must never silently restart.
  - Ignore or reject a duplicate start while a payment is running (idempotent).
  - Work runs in a service-owned coroutine scope that is cancelled in `onDestroy`.
  - On finish, publish the terminal state, then call `ServiceCompat.stopForeground(this, STOP_FOREGROUND_REMOVE)` and `stopSelf(startId)`. To leave a final "Payment complete" notification, **detach first, then post it**: while it is still the foreground notification the system keeps it non-cancellable and drops its `AUTO_CANCEL` flag (seen on a device), so posting it before `DETACH` gives a notification that cannot be tapped away.
  - Support cancel. Of a cancel and a finish that race, the first wins; the service fails only the payment it ran, never "whatever is running".
- Service → Dart: the service publishes to `PaymentProgressStore` (`StateFlow`), the process-wide coordination point: the plugin claims in it, the service runs against it, a cancel from the app or the notification writes to it, and every transition is one atomic step. `PaymentServicePlugin` collects it while the EventChannel is listened to. The service never references `FlutterEngine` or `Activity`.

## 5. Gradle and compliance

- Kotlin DSL only. Add `androidx.core:core-ktx` and `org.jetbrains.kotlinx:kotlinx-coroutines-android` with explicit versions (core-ktx 1.18.0: 1.19 needs compileSdk 37 and AGP 9.1; coroutines 1.11.0). Keep `compileSdk`/`targetSdk`/`minSdk` from the Flutter Gradle plugin unless there is a reason.
- JVM tests: JUnit 4 and `kotlinx-coroutines-test`, in `app/src/test/kotlin`. System access (files, packages, commands, `Build`, `Looper`, the `Window`) sits behind small ports, so no Android stubs are needed. Run them with `JAVA_HOME=<JDK 21> ./gradlew testDebugUnitTest` from `android/`; the task is flavor-free because both flavors compile the same sources.
- Guard every API above minSdk with `Build.VERSION.SDK_INT` + `@RequiresApi`, and write the API level in a comment next to the call.
- No deprecated APIs where a replacement exists: `ServiceCompat.stopForeground`, `PendingIntent.FLAG_IMMUTABLE`, `NotificationCompat`, `ContextCompat`.
- Release builds must work with R8. Don't rely on reflection.
- The **Gradle wrapper is committed** (`gradlew`, `gradlew.bat`, `gradle/wrapper/`), pinned to Gradle 8.14 with the distribution's SHA-256, because Flutter git-ignores it and a fresh clone (or CI) would have no `./gradlew`. Regenerate it with `gradle wrapper --gradle-version <v> --gradle-distribution-sha256-sum <sum>`; never copy Flutter's template jar, which identifies itself as Gradle 2.10. The official jar's checksum is published at `services.gradle.org/distributions/gradle-<v>-wrapper.jar.sha256`.
- **Android Lint** (`./gradlew :app:lintRetailDebug`, and `lintRetailRelease` after a `flutter build apk --release`, which rewrites the plugin registrant that raw Gradle compiles) reports no error. Its two version notes (Gradle 8.14, core-ktx 1.18) are pinned on purpose. A suppression carries its reason next to it.
- Backups are off on every version: `allowBackup="false"` and Android 12 data extraction rules that exclude every domain; the manifest test checks both, and the rules file is a declared input of the unit tests.
- Never branch on flavor in Kotlin. Brand-specific values (notification color, app name) come from `resValue`, flavor `res/` or Dart arguments.

## 6. Dart side of the bridge

- `features/<x>/data/datasources/<x>_platform_data_source.dart` receives a `MethodChannel`/`EventChannel` through its constructor, which makes it testable with `TestDefaultBinaryMessengerBinding`.
- It catches `PlatformException` → typed `Failure`, and `MissingPluginException` (iOS, tests) → `unknown`/unsupported state. It never throws past the repository.
- Event streams are exposed as domain streams (`Stream<ScreenRecordingState>`, `Stream<PaymentProgress>`), mapped once, and surfaced to the UI through `StreamProvider`s in the feature's `di/`. Presentation never imports `flutter/services.dart` for channels.
- Do not build a repository's event stream with `async*` while it waits on a quiet inner stream: cancelling an `async*` stream only takes effect at its next `yield`, so the native listener stays registered until the next event. Use a `StreamController` whose `onCancel` cancels the inner subscription.
- Riverpod 3 filters `StreamProvider` events with `==`. Make event entities `Equatable`, so that dropping identical consecutive states is intended rather than accidental.
- Channel providers (`MethodChannel`/`EventChannel` instances) are plain `Provider`s, so tests can override them.
- **Say what you swallow.** A channel source takes a `Logger` and warns wherever it turns a platform problem into something quieter: an error reply, a timeout, a malformed or error event, a failed permission request that does not stop the payment. It logs the **method and the error code** (or the type name), never the message, the arguments or a payload: a native message can carry anything. `MissingPluginException` (no native side) is expected and is not logged. The tests plant a card number in every native message and assert it never reaches a log (`nativeCanary`).
- Give method calls a **timeout** and turn it into an explicit failure (`UNAVAILABLE`): a call that is never answered must not leave the app waiting for ever, and "no answer" is as good a reason to refuse a payment as an error.
- Share **one native EventChannel subscription** between all Dart listeners (`ReplayLatest.empty(onFirstListener, onLastCancel, forgetOnLastCancel: true)`): open for the first, close after the last, replay the latest to each, never a value from before the reopen. The stream carries no errors: a malformed or error event is `unknown`.
- Flutter's `EventChannel` swallows a failed `listen` (for example `MissingPluginException`) and reports it through `FlutterError`, so with no native side the stream is silent, not erroring.
- Test the channel source against the same contract suite as the fake, with a Dart stand-in for the native side on the mock binary messenger (`test/features/security/helpers/native_security_simulator.dart`).

## 7. Self-check before finishing native work

- [ ] Every channel call replies exactly once, on main; no blocking work on main.
- [ ] Callbacks, scopes and sinks are released on detach, cancel or destroy; no Activity leaks across config changes.
- [ ] Every API > 24 is guarded and annotated; permissions are declared with the correct API scope.
- [ ] The FGS type is declared, the permission added, the start is user-initiated, the stop path is correct, and the timeout is handled.
- [ ] `Channels.kt`, `lib/core/platform/` and `docs/platform_channels.md` are in sync (a Dart test compares the first two).
- [ ] The JVM tests pass, and the behaviour that depends on a device was checked on one: screenshot and recents with `FLAG_SECURE`, root signals, the recording callback.
- [ ] A check that cannot run on a device shows up (the debug log lists inconclusive checks), instead of silently reading as clean.
- [ ] `flutter build apk --debug --flavor <each>` succeeds.
