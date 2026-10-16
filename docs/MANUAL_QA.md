# Manual QA checklist

Everything that needs a person. Whatever `adb` and the emulator can check is checked by the agent and
written down in `docs/platform_channels.md` ("Verified on a device"); what is left is here.

The whole list was meant to be run **once, at the end, on a physical phone** with a profile build. It was run once, on
2026-10-16, on one phone: see [Phone run, 2026-10-16](#phone-run-2026-10-16). An item with no reported result says
*not tested*, and a finding that depends on one says so wherever it is stated.

Items are grouped by milestone and appended as milestones land. Each has exact steps, the expected
result, and a place for the outcome.

## Phone run, 2026-10-16

- **Phone:** ZTE RedMagic 10 Pro, Android 16 (API 36).
- **Build:** the Retail profile APK in `dist/`, built at 12:34 and copied to the phone by hand (ADB installation needs a
  manufacturer account). It holds the code of `90862ac`, so it **predates the last three code commits** (`086992c` request and
  brand layout, `d50d208` confirmation cancellation, `d572cff` invalidation when the host request changes). The run was not
  repeated on the final code. Both brands were looked at (a profile build has the brand switcher).
- **Seen working:** the root check ("No root indicators found" showed, Pay was enabled, payments went through); `FLAG_SECURE` (screenshots
  blocked by the system, the app blacked out in Recents, and the saved screen recording shows the app area black); the live progress notification and Cancel; backgrounding during a
  payment and returning (the progress was shown); both brands' look; the demo panel scenarios; no bugs noticed.
- **Finding:** the phone's screen recorder did not make the app show a recording block, while the saved recording shows the app
  area black. That is the `M4-5` finding, **defense in depth**, in `docs/platform_channels.md`: `FLAG_SECURE` is verified against
  recording on the device. An emulator experiment (the stock recorder triggers the block with `FLAG_SECURE` on and off) points to
  the maker's recorder, not the secure window, as the reason for the silence on the phone.
- **Frame rate:** 120 FPS on the performance overlay with no visible drops. This is qualitative: the frame-timing harness
  (`M6-6`) was not run on the phone, so there are no phone numbers.
- **Not tested** (not explicitly checked, or not reported): the notification permission prompt, which Cancel path was used each
  time (the notification's or the app's), Utility's 1.6 s scan speed, and every item below that says
  *not tested*.

## How to run

- Phone: Android with USB debugging on, connected (`adb devices` lists it).
- Build and run a **profile** build, which keeps the demo panel and the brand switcher (both are
  hidden only in release):
  `flutter run --profile --flavor retail -d <device id>`
  (the native debug log needs a debuggable build; a profile build is not one, so use `--debug` when an
  item says to read `adb logcat`).
- Without a cable, run `tool/build_release_apks.sh`, copy the matching `dist/retail-profile-arm64.apk` or
  `dist/utility-profile-arm64.apk` to the phone, and install it by hand. The script builds both release APKs and both arm64
  profile APKs, with `SHA256SUMS` and `SOURCE_REVISION`; no ADB installation is needed.
- Note the phone's model and **Android version (API level)** in the table at the end: several items
  differ by API level.
- Fill in the Result column: ✅ as expected, ❌ with what happened, n/a with why, or *not tested*.

## Run the automated device suites first

Two suites drive the real app on an **emulator** and need no person; they are not part of CI (it has no device) and they do
not replace the phone: they cannot judge how a notification looks, the lock screen, another OEM's behavior or another API
level. Run them before the phone so that a regression is not mistaken for a device difference:

```bash
python3 tool/test_payment_lifecycle.py --device emulator-5554        # background and engine replacement mid-payment, each brand
PAYMENT_TEST_DEVICE=emulator-5554 PAYMENT_TEST_FLAVOR=retail \
  flutter drive --debug --no-dds --flavor retail -d emulator-5554 \
  --driver=test_driver/payment_integration.dart --target=integration_test/payment_flow_test.dart
```

They cover, on an emulator, the *software* half of `M5-7` (backgrounded) and `M5-8` (swiped away: the Activity and engine are
replaced while the process lives): the service keeps running and the receipt appears once. `M5-8` on the phone still checks
what the person sees, and a process killed by the system is a different case that no suite here covers.

## Recording the demo video

The demo video is recorded **from the emulator window with macOS screen capture** (Cmd+Shift+5, then
"Record Selected Portion" over the emulator window), not from inside Android. `FLAG_SECURE` blacks out
every capture made by Android itself (`adb screenrecord`, the Screen record tile, `scrcpy`, the
screenshot button), by design, on every build mode including Simulated. macOS captures the pixels of
the emulator window from outside the guest, so the payment screen shows.

## M4: device security

| # | Steps | Expected | Result |
|---|---|---|---|
| M4-1 | Open the demo panel (tune icon). Note the **Device reports** block: Root, Screen recording, Window protection. Close the panel. Open Quick Settings (swipe down twice), tap the **Screen record** tile (add it with the pencil icon if it is missing), choose **Record entire screen**, press **Start**. Go back to the app. Wait about two seconds. | The page shows **"Payment is paused while the screen is being recorded."** with the hint "This continues by itself when the recording stops.", and **Pay is disabled**. Reopen the panel: Screen recording says **Detected**. *Write down how many seconds it took.* | ❌ as written, and expected (see M4-5): with the system recorder running, nothing changed in the app and no recording block appeared. |
| M4-2 | Stop the recording (status-bar chip, or the tile again). | Within about two seconds the page returns to **"No root indicators found"** with Pay enabled, with no tap. The panel reads **Not detected**. | n/a: no block appeared, so there was nothing to clear. |
| M4-3 | Repeat M4-1 and M4-2 choosing **Record a single app** and picking the app. | Same as M4-1 and M4-2. *Write down whether it differs from entire-screen.* | *not tested*: which recording mode (entire screen or single app) was used was not noted. |
| M4-4 | Open the recorded video (Photos or Files). | The app window is **black** in the video (`FLAG_SECURE`). The rest of the screen (status bar, shade) is visible. | ✅ The saved screen recording was checked on the phone: the app area is black. |
| M4-5 | **If nothing changed in M4-1 and M4-3** (the readout stays Not detected the whole time): this is the finding "defense in depth". Report it as such. If it changed: report "verified". | The result decides the wording in the [platform contract](platform_channels.md#recording-callback-while-the-window-is-secure-defense-in-depth) and [Prompt Log highlight 3](ai/PROMPT_LOG.md#3-an-emulator-experiment-refuted-the-recording-hypothesis): *verified* (the callback fires with `FLAG_SECURE` on) or *defense in depth* (it never fires for a secure window; `FLAG_SECURE` already blacks the recording out). | **Defense in depth** (final). On Android 16 (ZTE RedMagic 10 Pro, the OEM recorder) the recording callback did not fire while `FLAG_SECURE` was set, and the saved recording shows the app area black (`M4-4`): `FLAG_SECURE` is **device-verified** against recording. The first hypothesis, that a secure window is left out of the callback, did **not** survive an emulator experiment: the stock recorder (Pixel_9, API 36) triggers the recording block with `FLAG_SECURE` on (4 of 4 runs) and off (3 of 3), while its capture of the secure window is black. So the silence on the phone more likely comes from the OEM recorder not being reported to the callback; that is **not proven** (it was not tried on the phone with a window without `FLAG_SECURE`). The detection stays as an extra layer that cannot be relied on across makers; `FLAG_SECURE` is the primary control. |
| M4-6 | Press the hardware screenshot buttons on the payment screen. | The phone says it cannot take a screenshot because of the security policy (or saves a black image). The Recents (overview) card for the app is blank. | ✅ Screenshots are blocked by the system; the app is blacked out in Recents (swipe up). |
| M4-7 | On a phone **below Android 15 (API 35)**, open the panel. | Screen recording reads **Unknown**, never Not detected. Starting a recording does **not** block the page. *Skip if the phone is on API 35 or above.* | n/a: the phone is on Android 16 (API 36). |
| M4-8 | Panel, **Device reports**. | Root: **Not detected** on an unrooted phone (or the signals that fired, on a rooted one). Window protection: **Active**. | ✅ Root: "No root indicators found" showed, Pay was enabled and payments went through. The panel's Device reports block was not noted separately. |
| M4-9 | Panel: switch **Device security** to *Simulated*, then back to *Real*. | The screen stays black in a screenshot attempt (M4-6) in both modes. Real shows the Device reports block again. | *not tested*: the demo panel scenarios worked, but the screenshot attempt in each source mode was not noted. |

## M5: payment foreground service

What `adb` could check on the emulator (service type, notification record, live progress, cancel, background,
swipe-away, force-stop, a release build) is in `docs/platform_channels.md`, "Verified on a device (payment)". These
items need a person, or a phone that is not an emulator. Use the application id `com.hypertenant.secure_payment_portal.retail`
(`.utility` for the other flavor). For the permission items start from a state where the notification permission has
not been answered: uninstall and reinstall, or Settings > Apps > Retail Shop > Permissions > Notifications.

| # | Steps | Expected | Result |
|---|---|---|---|
| M5-1 | **Android 13+, fresh install.** Get to the review page and tap **Pay**. | The system asks **"Allow Retail Shop to send you notifications?"** *before* the payment starts. Choose **Allow**. The payment then runs and ends on the receipt. A "Processing your payment" notification appears while it runs. | *not tested*: the notification permission prompt was not explicitly checked. |
| M5-2 | **Permission denied.** Start from a fresh install, tap **Pay**, choose **Don't allow**. Then pay once more. | The payment still runs to the receipt, and **no notification** appears. *Write down whether the system asks again on the second payment* (Android stops asking after two denials). | *not tested*. |
| M5-3 | **Look of the notification.** Allow the permission. Tap **Pay** and pull the shade down at once. Expand the card. | It sits in the **Silent** section (no sound, no vibration, no heads-up banner). It reads "Processing your payment" with the app's small icon (a clean white glyph, **not** a grey square), a **progress bar that moves** about twice a second without flicker, and a **Cancel** button when expanded. Utility flavor: the app name is "Utility Pay". | ✅ in part: the live progress notification appeared. Its look (Silent section, icon, bar, Cancel when expanded, Utility's name) was not itemised. |
| M5-4 | **Cancel from the shade.** Start a payment, pull the shade down, expand the card, tap **Cancel**. | The notification disappears at once, and the app (reopen it) shows **"Payment cancelled"** with Try again. On Android 13+ the shade's active-apps list (the "N apps are active" row) no longer lists the app. | ✅ in part: Cancel works. Which path was used each time (the notification's Cancel or the app's) was not recorded, so the notification's own Cancel is not separately confirmed on the phone. |
| M5-5 | **Lock screen.** Start a payment, press the power button, then wake the screen **without unlocking**. | The notification shows **nothing about the payment**: either the system's "Sensitive notification content hidden" placeholder or generic text only. **No amount, no merchant.** *Write down which.* | *not tested*. |
| M5-6 | **Final notification.** Start a payment, press Home, wait about 10 seconds. | A **"Payment complete"** notification is left in the shade (not ongoing). Swipe it away: it goes. Repeat and **tap** it instead: the app opens on the receipt and the notification is removed. | *not tested*. |
| M5-7 | **Backgrounded.** Start a payment, press Home, wait for it to finish, open the app from the launcher. | The receipt is shown. There is **one** payment, not two. | ✅ Backgrounded during a payment and returned: the progress was shown. The final receipt and "one payment, not two" were not itemised. |
| M5-8 | **Swiped away.** Start a payment, open Recents, swipe the app away, watch the shade for a few seconds, open the app again. | The notification keeps updating after the swipe, and the app reopens on the receipt (or on the review page if the phone killed the process: *write down which*). | *not tested*. |
| M5-9 | **Notifications switched off.** Settings > Apps > Retail Shop > Notifications: off. Pay. | The payment completes, no notification, no crash. | *not tested*. |
| M5-10 | **Battery saver.** Turn battery saver on and pay with the screen on; then pay again and lock the screen straight away. | Both payments complete (about 8 seconds on the screen-on one). *Write down the time of the locked one.* | *not tested*. |
| M5-11 | **Stop from the active-apps list** (Android 13+). Start a payment, pull the shade, tap the "N apps are active" row, and **Stop** the app. Reopen it. | The notification is gone and the app starts from a clean review page. The interrupted payment is neither confirmed nor failed (documented behaviour for a killed process). | *not tested*. |
| M5-12 | **API levels** (only if more than one phone is at hand). Below Android 13: no permission prompt, the notification appears at once. Below 14 and 10: the payment works, no crash (the service type is masked by `ServiceCompat`). | As described. *Fill in the Devices table for each phone.* | n/a: one phone. |

Covered by JVM tests only, not reproducible by hand: the refusal to start the service from the background
(`ForegroundServiceStartNotAllowedException`), the 3 minute `onTimeout`, and the "Payment failed" notification.

## M6: the security scan

What the emulator could check is in [the performance appendix](ai/appendix/performance.md#frame-timing) (frame timing, profile mode) and in the tests (no
rebuilds, one repaint layer, the maths). `FLAG_SECURE` blacks out any screenshot of this page, so what the scan *looks like*
in motion, and how it runs on real hardware, is for a person. Use a **profile** build
(`flutter run --profile --flavor retail -d <phone>`; the demo panel is there). For a 120 Hz phone, check first that the display
really runs fast: `adb shell dumpsys display | grep -i "refreshRate\|fps"`, and Settings > Display > Smooth display on.

| # | Steps | Expected | Result |
|---|---|---|---|
| M6-1 | **Retail.** Open the app (Retail flavor). Watch the security card from the moment the page appears. | A radar with a gold sweep turning clockwise and soft rings expanding from the centre. The sweep goes **all the way round once** (about 2.4 s), then fades into the shield and **"No root indicators found"**, and Pay becomes enabled just then. No stutter, no flicker. | ✅ in part: both brands look right and no bug was noticed. The single revolution and the verdict timing were not itemised. |
| M6-2 | **Utility.** The same on the Utility flavor, or switch brand in the app bar. | The sky-blue sweep turns once in about 1.6 s with quicker rings. *Does it look frantic or fine? If it is too fast, say so: the minimum period is one constant.* | *not tested*: Utility's 1.6 s scan speed was not explicitly checked, so whether it looks frantic is still open. |
| M6-3 | **Held scan.** Demo panel > Device security > **Simulated** > Device check takes **15 s**. Watch the card for the whole 15 s. | The sweep and the rings run smoothly for the whole time, with no stutter, no change in speed and no jump when the sweep passes the top. The grid, rings and ticks stay perfectly still. The verdict appears at the end of a revolution (up to a period after the 15 s). | *not tested*. |
| M6-4 | **The loop has no seam.** During M6-3 watch at least three revolutions, looking at the top of the circle and at the centre. | No jump of the sweep when it passes 12 o'clock. A ring appears at the centre without popping and fades out at the rim without a visible cut. | *not tested*. |
| M6-5 | **Reduced motion.** Settings > Accessibility > **Remove animations** (or "Reduce motion"). Open the payment page. | The scan is drawn **still** (a sweep wedge and three rings), nothing moves, and the verdict shows **at once**: Pay is enabled without waiting. Turn the setting off again and re-open the page: the scan moves. | *not tested*. |
| M6-6 | **Frame timing on the phone.** Run the command from the README with `-d <phone id>` and `--dart-define=DEVICE_NAME="<model, Android version>"` (about 6 minutes, phone unlocked and awake). Paste `build/scan_performance/summary.md` below. | Mode `profile`, FPS close to the display's rate (60, 90 or 120), **0 or almost 0 frames over budget** for the scan, build and raster times under the budget (16.7 ms at 60 Hz, 8.3 ms at 120 Hz) and in the same range as the spinner reference. *If a 120 Hz phone reports 60 Hz, say so: the display, not the app, is limiting it.* | not run on the phone: the harness needs an ADB install, which this phone only allows with a manufacturer account. There are no phone numbers. |
| M6-7 | **Performance overlay.** Demo panel > Display > Performance overlay on, then M6-3. | Both graphs stay under the green budget line while the scan runs; no red bars. | ✅ qualitative: 120 FPS on the performance overlay and no visible drops. Not a measurement. |
| M6-8 | **Only the radar repaints.** Debug build (`flutter run --debug`), DevTools > Inspector > **Highlight repaints**, then M6-3. | Only the radar layer changes colour frame after frame; the text beside it, the card and the rest of the page do not. Then **Track widget rebuilds**: no rebuild counts rise during the scan. | *not tested*. |
| M6-9 | **Sustained.** Run M6-3 four times in a row (about a minute), screen on. | No visible slow-down; the phone is not noticeably hot. | *not tested*. |
| M6-10 | **Battery saver.** Turn it on, repeat M6-3. | Still smooth (Android may lower the refresh rate to 60 Hz; that is fine if it is steady). | *not tested*. |
| M6-11 | **Away and back.** During M6-3 press Home, wait 5 s, return. | The scan carries on from where the clock is, with no jump or freeze; the verdict still arrives at the end of a revolution. | *not tested*. |

Frame timing result (M6-6), paste the table here:

Not run on the phone (`M6-6`). The only phone observation is qualitative: 120 FPS on the performance overlay and no visible
drops. The numbers in the README and in `docs/ai/appendix/performance.md` are from the emulator.

## Devices

| Phone model | Android version / API level | Build | Date |
|---|---|---|---|
| ZTE RedMagic 10 Pro | Android 16 (API 36) | Retail profile APK built at 12:34, code of `90862ac` | 2026-10-16 |

## Review-fix regression checks (schema v2)

These scenarios have automated coverage; the phone run of 2026-10-16 did not cover them. Invoking a saved stale PendingIntent requires an instrumented trigger; the JVM cancellation-action regression is the current evidence for that case.

| Steps | Expected | Result |
|---|---|---|
| Enable reduced motion, cancel and immediately retry the same bill repeatedly. | Distinct attempts; no hang, old receipt or premature completion; one worker and notification. | *not tested* on the phone. |
| Invoke an old notification Cancel action while a replacement attempt runs. | The replacement continues; its own Cancel action works. | *not tested* on the phone. |
| On a fresh install leave the notification prompt open and start a recording before answering. | Security is read after preparation; a detected recording blocks native start. Callback behavior under FLAG_SECURE is the separate `M4-5` finding (defense in depth). | *not tested* on the phone. |
| Change brand or leave the page during permission preparation or the final security read. | The obsolete confirmation never starts processing. Already accepted work follows the documented service lifecycle. | *not tested* on the phone. |
| Attempt cancellation while the bridge is unavailable, then restore it. | A visible error accompanies continuing progress; retry cancels the matching attempt. | *not tested* on the phone. |

**Recording block after the root and watchdog changes (emulator, 2026-10-16).** Checked by the developer on the Pixel_9
emulator (API 36), by hand, after the root-monotonicity and post-acceptance watchdog commits (`8a9a8da`, `2434136`):
recording with the shade's **Screen record** tile triggers the recording block in the app. The emulator's own host-side
recorder does not trigger it, which is expected (it is not an in-guest `MediaProjection` capture, which is what the
callback reports). Only the appearance of the block was reported; its lifting after the recording stops
was not re-checked in this round (the earlier experiment is under
[the platform contract](platform_channels.md#recording-callback-while-the-window-is-secure-defense-in-depth)).


## In-app frame statistics without ADB (debug/profile)

1. Sideload the matching arm64 profile APK from `dist/`. Use profile for meaningful timing; debug adds framework overhead.
2. Open the tune icon → **Display**. The readout shows frames since reset, samples in the rolling 600-frame window,
   the display's reported refresh rate, and p50/p90/p99/worst build and raster milliseconds.
3. Tap **Reset frame statistics**. For a longer scan, select simulated device security and a 15 s device check, then
   restart the payment flow. Close the panel, observe the scenario, and reopen Display to read the values.
4. Record both flavors, the phone/OS, display setting, frame count/window size and all eight timing numbers in the
   [performance appendix](ai/appendix/performance.md#phone-frame-statistics). Repeat after resetting for each scenario.
5. The collector stays active while the panel is closed and unregisters on app-widget disposal. Timings cover the whole
   app, including panel transitions and its once-per-second readout updates; they are not an isolated scan benchmark.
   Display Hz is the rate reported by Flutter's display, not a measured FPS value. Do not claim 120 FPS from that field alone.

**Result:** not yet run on the phone. No new phone measurements are claimed.

## Run it

### Requirements

- Flutter 3.41.9 (Dart 3.11.5, see `environment.sdk` in `pubspec.yaml`), the version CI pins.
- Android SDK 36.
- **JDK 21** for Android builds: it is what CI and the author's machine use. The code targets Java 17 bytecode, but no
  other JDK was tried. JDK 25 is known to fail: Gradle configuration stops with `IllegalArgumentException: 25.0.1`
  because the Kotlin Gradle plugin (2.2.20) cannot parse that version.
  - Point Flutter at a JDK 21 once: `flutter config --jdk-dir="<path to JDK 21>"`, then check with `flutter doctor -v`.
  - Raw Gradle calls (`./gradlew …`) do not read that setting. Prefix them for that command:
    `JAVA_HOME="<path to JDK 21>" ./gradlew …`.
- `jq` for `tool/build_release_apks.sh`; ImageMagick only to regenerate launcher icons.

### Flavors

One Android flavor per brand, named after the brand id. `--flavor` is required: a plain `flutter run` or
`flutter build apk` fails, because no flavor-less APK exists.

```bash
flutter run --flavor retail                  # or utility; add --profile to keep the demo panel and run fast
flutter build apk --debug --flavor retail
flutter build apk --release --flavor utility
tool/build_release_apks.sh                   # every brand: release + arm64 profile APKs in dist/, SHA256SUMS and SOURCE_REVISION
```

The build script records the source HEAD in `dist/SOURCE_REVISION` and hashes all four APKs in `dist/SHA256SUMS`.

APKs land in `build/app/outputs/flutter-apk/` as `app-<flavor>-<mode>.apk`. Both brands install side by side
(`com.hypertenant.secure_payment_portal.retail` and `.utility`).

**Debug and profile builds** have the demo tools (brand switcher, demo panel, performance overlay). **Release builds do
not**, by design: they are what a user would get.

### Release signing

`flutter build apk --release --flavor <brand>` produces an APK signed with the **debug keys**. That is deliberate: the
repository holds no keystore and no secret, so anyone can build and install a release APK. These APKs are for review, not
for a store, and an APK from CI will not install over one built on another machine (different debug key). A store release
needs a real signing config (a keystore and its passwords, supplied from outside the repository, for example from CI
secrets), which is not part of this project.

## Tests and CI

```bash
dart format --set-exit-if-changed lib test integration_test test_driver
flutter analyze                                  # zero issues
flutter test                                     # 906 Dart tests
(cd android && JAVA_HOME="<path to JDK 21>" ./gradlew testDebugUnitTest)   # 235 Kotlin JVM tests
flutter build apk --debug --flavor retail && flutter build apk --debug --flavor utility
```

- **Dart.** Domain and policy; data sources against the same contract suites as their fakes (the channel sources run
  unchanged against a Dart stand-in for the native side); notifiers through `ProviderContainer`; widgets; every registered
  brand; regex layering guardrails (not architectural proof); the documentation links.
- **Kotlin.** The ports, root checks, reply-once and threading, the secure window count, the payment store, session,
  notification throttle and handlers, and a guard over the manifest (permissions, one exported component, a
  `shortService`-only service, backups off).
- **Mutation checks.** These are targeted manual mutations, not a comprehensive mutation score. The review found two
  surviving mutations (unscoped failure handling and the restart generation guard); regression tests now cover both.
  Results and limits are recorded in the [review summary](ai/appendix/review.md).
- **CI** (`.github/workflows/ci.yml`) runs the format check, analysis and both test suites on every push to `main` and every
  pull request, then builds a release APK per brand (the list comes from `android/brands.json`) and uploads it as an
  artifact. Flutter 3.41.9, Temurin 21, every action pinned to a commit SHA.
- **Device suites (an emulator, not in CI).** Two suites drive the real app on a device, and neither runs in CI because CI has
  no device. Each takes a minute or two and needs an emulator (they reset app data and grant the notification
  permission with `adb`, and refuse a physical phone):
  - `integration_test/payment_flow_test.dart` runs the payment flow through the real Kotlin plugin and foreground service, for
    every registered brand: a cancelled and retried payment completes only the new attempt, and a payment whose request
    changes while the final security read is pending never starts.
    ```bash
    PAYMENT_TEST_DEVICE=emulator-5554 PAYMENT_TEST_FLAVOR=retail \
      flutter drive --debug --no-dds --flavor retail -d emulator-5554 \
      --driver=test_driver/payment_integration.dart --target=integration_test/payment_flow_test.dart
    ```
  - `tool/test_payment_lifecycle.py` pays, then sends the app to the background, and then replaces its Activity and Flutter
    engine mid-payment, and checks that the service carries on and the receipt appears once. One command runs every brand
    (`--flavor retail` for one):
    ```bash
    python3 tool/test_payment_lifecycle.py --device emulator-5554
    ```
  The frame timing of the scan (`integration_test/scan_performance_test.dart`, see [frame timing](ai/appendix/performance.md#frame-timing)) is a
  third device test, also outside CI.
- **On a phone.** What an emulator cannot show is a checklist for one run on a phone: [docs/MANUAL_QA.md](MANUAL_QA.md).
  It was run once, on 2026-10-16, on a ZTE RedMagic 10 Pro (Android 16), with its results and the items *not tested* in the
  same file.
  [docs/DEMO_SCRIPT.md](DEMO_SCRIPT.md) is the shot list for the demo video, which is recorded from the emulator window
  with macOS screen capture, because `FLAG_SECURE` blacks out any capture made inside Android.

## Known limitations

- **Android only.** iOS compiles (a simulator build was checked) but has no native side. A silent payment EventChannel
  reaches a blocked, unavailable state after the 5 s startup deadline; security failures also block confirmation. This
  makes startup fail closed rather than wait indefinitely. See the platform-channel contract for recovery behavior.
- **Release APKs are debug-signed** (see [Release signing](MANUAL_QA.md#release-signing)).
- **Root detection is heuristic** and can be bypassed (renamed packages, hiding tools); Play Integrity is out of scope.
- **Screen recording detection needs Android 15.** Below it the state is `unknown` and allowed. It is **defense in depth**:
  on a ZTE RedMagic 10 Pro (Android 16, the phone's own recorder) the callback did not fire and no recording block appeared,
  while the stock recorder on an emulator does trigger it, with `FLAG_SECURE` on or off. It cannot be relied on across makers
  (the likely reason, that the phone maker's recorder is not reported to the callback, is not proven). `FLAG_SECURE` is the
  primary control, and the saved recording shows the app area black on the phone and on the emulator (`M4-5`,
  [details](platform_channels.md)).
- **Payments are simulated.** The native processing always succeeds; declines and failures are simulated scenarios. A killed
  process loses an in-flight payment (the state is in memory, the service is not sticky): a real backend would need an
  idempotency key and reconciliation, described in [the appendix](ai/appendix/payments-in-production.md).
  `shortService` stops after about three minutes, fine for this simulation and not for a long real call.
- **The verdict dwell is a product cost:** Pay is enabled 1.6 to 2.4 s after the check starts, on every visit.
- **Frame timing was measured on an emulator.** On the phone the app showed 120 FPS on the performance overlay with no visible
  drops, which is an observation; the harness was not run there. No numbers are claimed for 90 or 120 Hz or a real GPU.
- **The phone run was one run on one phone, before these review fixes and three earlier code commits.** The wire contract is
  final. The notification permission prompt, the lock screen, swiping the app away, other Android versions, battery saver and
  Utility's 1.6 s scan speed were not tested; each is marked *not tested* in `docs/MANUAL_QA.md`.
- **Money and dates are not locale-aware.** Amounts are integer minor units in a `Money` value object, never `double`, and
  format as `$1,234.50`; receipts show UTC time. Neither uses `intl`, so grouping, symbol position and date order are fixed.
- **Light theme only** (tokens are brightness-agnostic, so a dark set can be added).
