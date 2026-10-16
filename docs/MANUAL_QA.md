# Manual QA checklist

Everything that needs a person. Whatever `adb` and the emulator can check is checked by the agent and
written down in `docs/platform_channels.md` ("Verified on a device"); what is left is here.

The whole list is run **once, at the end, on a physical phone** with a profile build, and the results
are reported in one go. Until then, a finding that depends on an item below is marked **pending manual
verification** wherever it is stated.

Items are grouped by milestone and appended as milestones land. Each has exact steps, the expected
result, and a place for the outcome.

## How to run

- Phone: Android with USB debugging on, connected (`adb devices` lists it).
- Build and run a **profile** build, which keeps the demo panel and the brand switcher (both are
  hidden only in release):
  `flutter run --profile --flavor retail -d <device id>`
  (the native debug log needs a debuggable build; a profile build is not one, so use `--debug` when an
  item says to read `adb logcat`).
- Note the phone's model and **Android version (API level)** in the table at the end: several items
  differ by API level.
- Fill in the Result column: ✅ as expected, ❌ with what happened, or n/a with why.

## Recording the demo video

The demo video is recorded **from the emulator window with macOS screen capture** (Cmd+Shift+5, then
"Record Selected Portion" over the emulator window), not from inside Android. `FLAG_SECURE` blacks out
every capture made by Android itself (`adb screenrecord`, the Screen record tile, `scrcpy`, the
screenshot button), by design, on every build mode including Simulated. macOS captures the pixels of
the emulator window from outside the guest, so the payment screen shows.

## M4: device security

| # | Steps | Expected | Result |
|---|---|---|---|
| M4-1 | Open the demo panel (tune icon). Note the **Device reports** block: Root, Screen recording, Window protection. Close the panel. Open Quick Settings (swipe down twice), tap the **Screen record** tile (add it with the pencil icon if it is missing), choose **Record entire screen**, press **Start**. Go back to the app. Wait about two seconds. | The page shows **"Payment is paused while the screen is being recorded."** with the hint "This continues by itself when the recording stops.", and **Pay is disabled**. Reopen the panel: Screen recording says **Detected**. *Write down how many seconds it took.* | |
| M4-2 | Stop the recording (status-bar chip, or the tile again). | Within about two seconds the page returns to **"This device is verified"** with Pay enabled, with no tap. The panel reads **Not detected**. | |
| M4-3 | Repeat M4-1 and M4-2 choosing **Record a single app** and picking the app. | Same as M4-1 and M4-2. *Write down whether it differs from entire-screen.* | |
| M4-4 | Open the recorded video (Photos or Files). | The app window is **black** in the video (`FLAG_SECURE`). The rest of the screen (status bar, shade) is visible. | |
| M4-5 | **If nothing changed in M4-1 and M4-3** (the readout stays Not detected the whole time): this is the finding "defense in depth". Report it as such. If it changed: report "verified". | The result decides the wording in `docs/platform_channels.md` and PROMPT_LOG entry 06: *verified* (the callback fires with `FLAG_SECURE` on) or *defense in depth* (it never fires for a secure window; `FLAG_SECURE` already blacks the recording out). | |
| M4-6 | Press the hardware screenshot buttons on the payment screen. | The phone says it cannot take a screenshot because of the security policy (or saves a black image). The Recents (overview) card for the app is blank. | |
| M4-7 | On a phone **below Android 15 (API 35)**, open the panel. | Screen recording reads **Unknown**, never Not detected. Starting a recording does **not** block the page. *Skip if the phone is on API 35 or above.* | |
| M4-8 | Panel, **Device reports**. | Root: **Not detected** on an unrooted phone (or the signals that fired, on a rooted one). Window protection: **Active**. | |
| M4-9 | Panel: switch **Device security** to *Simulated*, then back to *Real*. | The screen stays black in a screenshot attempt (M4-6) in both modes. Real shows the Device reports block again. | |

## M5: payment foreground service

What `adb` could check on the emulator (service type, notification record, live progress, cancel, background,
swipe-away, force-stop, a release build) is in `docs/platform_channels.md`, "Verified on a device (payment)". These
items need a person, or a phone that is not an emulator. Use the application id `com.hypertenant.secure_payment_portal.retail`
(`.utility` for the other flavor). For the permission items start from a state where the notification permission has
not been answered: uninstall and reinstall, or Settings > Apps > Retail Shop > Permissions > Notifications.

| # | Steps | Expected | Result |
|---|---|---|---|
| M5-1 | **Android 13+, fresh install.** Get to the review page and tap **Pay**. | The system asks **"Allow Retail Shop to send you notifications?"** *before* the payment starts. Choose **Allow**. The payment then runs and ends on the receipt. A "Processing your payment" notification appears while it runs. | |
| M5-2 | **Permission denied.** Start from a fresh install, tap **Pay**, choose **Don't allow**. Then pay once more. | The payment still runs to the receipt, and **no notification** appears. *Write down whether the system asks again on the second payment* (Android stops asking after two denials). | |
| M5-3 | **Look of the notification.** Allow the permission. Tap **Pay** and pull the shade down at once. Expand the card. | It sits in the **Silent** section (no sound, no vibration, no heads-up banner). It reads "Processing your payment" with the app's small icon (a clean white glyph, **not** a grey square), a **progress bar that moves** about twice a second without flicker, and a **Cancel** button when expanded. Utility flavor: the app name is "Utility Pay". | |
| M5-4 | **Cancel from the shade.** Start a payment, pull the shade down, expand the card, tap **Cancel**. | The notification disappears at once, and the app (reopen it) shows **"Payment cancelled"** with Try again. On Android 13+ the shade's active-apps list (the "N apps are active" row) no longer lists the app. | |
| M5-5 | **Lock screen.** Start a payment, press the power button, then wake the screen **without unlocking**. | The notification shows **nothing about the payment**: either the system's "Sensitive notification content hidden" placeholder or generic text only. **No amount, no merchant.** *Write down which.* | |
| M5-6 | **Final notification.** Start a payment, press Home, wait about 10 seconds. | A **"Payment complete"** notification is left in the shade (not ongoing). Swipe it away: it goes. Repeat and **tap** it instead: the app opens on the receipt and the notification is removed. | |
| M5-7 | **Backgrounded.** Start a payment, press Home, wait for it to finish, open the app from the launcher. | The receipt is shown. There is **one** payment, not two. | |
| M5-8 | **Swiped away.** Start a payment, open Recents, swipe the app away, watch the shade for a few seconds, open the app again. | The notification keeps updating after the swipe, and the app reopens on the receipt (or on the review page if the phone killed the process: *write down which*). | |
| M5-9 | **Notifications switched off.** Settings > Apps > Retail Shop > Notifications: off. Pay. | The payment completes, no notification, no crash. | |
| M5-10 | **Battery saver.** Turn battery saver on and pay with the screen on; then pay again and lock the screen straight away. | Both payments complete (about 8 seconds on the screen-on one). *Write down the time of the locked one.* | |
| M5-11 | **Stop from the active-apps list** (Android 13+). Start a payment, pull the shade, tap the "N apps are active" row, and **Stop** the app. Reopen it. | The notification is gone and the app starts from a clean review page. The interrupted payment is neither confirmed nor failed (documented behaviour for a killed process). | |
| M5-12 | **API levels** (only if more than one phone is at hand). Below Android 13: no permission prompt, the notification appears at once. Below 14 and 10: the payment works, no crash (the service type is masked by `ServiceCompat`). | As described. *Fill in the Devices table for each phone.* | |

Covered by JVM tests only, not reproducible by hand: the refusal to start the service from the background
(`ForegroundServiceStartNotAllowedException`), the 3 minute `onTimeout`, and the "Payment failed" notification.

## M6: the security scan

What the emulator could check is in `docs/ai/AI_INSIGHT_REPORT.md` §4 (frame timing, profile mode) and in the tests (no
rebuilds, one repaint layer, the maths). `FLAG_SECURE` blacks out any screenshot of this page, so what the scan *looks like*
in motion, and how it runs on real hardware, is for a person. Use a **profile** build
(`flutter run --profile --flavor retail -d <phone>`; the demo panel is there). For a 120 Hz phone, check first that the display
really runs fast: `adb shell dumpsys display | grep -i "refreshRate\|fps"`, and Settings > Display > Smooth display on.

| # | Steps | Expected | Result |
|---|---|---|---|
| M6-1 | **Retail.** Open the app (Retail flavor). Watch the security card from the moment the page appears. | A radar with a gold sweep turning clockwise and soft rings expanding from the centre. The sweep goes **all the way round once** (about 2.4 s), then fades into the shield and **"This device is verified"**, and Pay becomes enabled just then. No stutter, no flicker. | |
| M6-2 | **Utility.** The same on the Utility flavor, or switch brand in the app bar. | The sky-blue sweep turns once in about 1.6 s with quicker rings. *Does it look frantic or fine? If it is too fast, say so: the minimum period is one constant.* | |
| M6-3 | **Held scan.** Demo panel > Device security > **Simulated** > Device check takes **15 s**. Watch the card for the whole 15 s. | The sweep and the rings run smoothly for the whole time, with no stutter, no change in speed and no jump when the sweep passes the top. The grid, rings and ticks stay perfectly still. The verdict appears at the end of a revolution (up to a period after the 15 s). | |
| M6-4 | **The loop has no seam.** During M6-3 watch at least three revolutions, looking at the top of the circle and at the centre. | No jump of the sweep when it passes 12 o'clock. A ring appears at the centre without popping and fades out at the rim without a visible cut. | |
| M6-5 | **Reduced motion.** Settings > Accessibility > **Remove animations** (or "Reduce motion"). Open the payment page. | The scan is drawn **still** (a sweep wedge and three rings), nothing moves, and the verdict shows **at once**: Pay is enabled without waiting. Turn the setting off again and re-open the page: the scan moves. | |
| M6-6 | **Frame timing on the phone.** Run the command from the README with `-d <phone id>` and `--dart-define=DEVICE_NAME="<model, Android version>"` (about 6 minutes, phone unlocked and awake). Paste `build/scan_performance/summary.md` below. | Mode `profile`, FPS close to the display's rate (60, 90 or 120), **0 or almost 0 frames over budget** for the scan, build and raster times under the budget (16.7 ms at 60 Hz, 8.3 ms at 120 Hz) and in the same range as the spinner reference. *If a 120 Hz phone reports 60 Hz, say so: the display, not the app, is limiting it.* | |
| M6-7 | **Performance overlay.** Demo panel > Display > Performance overlay on, then M6-3. | Both graphs stay under the green budget line while the scan runs; no red bars. | |
| M6-8 | **Only the radar repaints.** Debug build (`flutter run --debug`), DevTools > Inspector > **Highlight repaints**, then M6-3. | Only the radar layer changes colour frame after frame; the text beside it, the card and the rest of the page do not. Then **Track widget rebuilds**: no rebuild counts rise during the scan. | |
| M6-9 | **Sustained.** Run M6-3 four times in a row (about a minute), screen on. | No visible slow-down; the phone is not noticeably hot. | |
| M6-10 | **Battery saver.** Turn it on, repeat M6-3. | Still smooth (Android may lower the refresh rate to 60 Hz; that is fine if it is steady). | |
| M6-11 | **Away and back.** During M6-3 press Home, wait 5 s, return. | The scan carries on from where the clock is, with no jump or freeze; the verdict still arrives at the end of a revolution. | |

Frame timing result (M6-6), paste the table here:

```
(paste summary.md)
```

## Devices

| Phone model | Android version / API level | Build | Date |
|---|---|---|---|
| | | | |

## Review-fix regression checks (schema v2)

These scenarios have automated coverage and still need a device run. Invoking a saved stale PendingIntent requires an instrumented trigger; the JVM cancellation-action regression is the current evidence for that case.

| Steps | Expected | Result |
|---|---|---|
| Enable reduced motion, cancel and immediately retry the same bill repeatedly. | Distinct attempts; no hang, old receipt or premature completion; one worker and notification. | |
| Invoke an old notification Cancel action while a replacement attempt runs. | The replacement continues; its own Cancel action works. | |
| On a fresh install leave the notification prompt open and start a recording before answering. | Security is read after preparation; a detected recording blocks native start. Callback behavior under FLAG_SECURE remains the separate M4 check. | |
| Change brand or leave the page during permission preparation or the final security read. | The obsolete confirmation never starts processing. Already accepted work follows the documented service lifecycle. | |
| Attempt cancellation while the bridge is unavailable, then restore it. | A visible error accompanies continuing progress; retry cancels the matching attempt. | |
