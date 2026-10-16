# Demo video: shot list for one take

About six minutes, one continuous recording of the **emulator window**, with the terminal visible beside it for one shot.
It shows both launcher icons, the Retail flow (scan, pay, live notification, background, cancel), the Utility flow, the
debug brand switch, simulated root and recording blocks, the `FLAG_SECURE` proof and the performance overlay.

## How to record

Record the emulator window **from outside Android**: macOS `Cmd+Shift+5`, *Record Selected Portion*, drawn over the emulator
window (and the terminal for shot 8), microphone as you like.

Do not record with `adb screenrecord`, the Screen record tile, `scrcpy` or the emulator's own recorder. The payment page
sets `FLAG_SECURE` in every mode, simulated or not, so every capture made inside Android shows it black. That is the feature,
and shot 8 uses it. macOS captures the pixels of the emulator window from the host, so the page shows.

## Before the take

1. **Profile builds, not release.** The demo panel, the brand switcher and the performance overlay exist only in non-release
   builds, by design.
   ```bash
   flutter build apk --profile --flavor retail
   flutter build apk --profile --flavor utility
   ```
2. **A first-run state**, so the notification prompt appears. Start the Pixel_9 emulator, then install both fresh:
   ```bash
   adb uninstall com.hypertenant.secure_payment_portal.retail
   adb uninstall com.hypertenant.secure_payment_portal.utility
   adb install build/app/outputs/flutter-apk/app-retail-profile.apk
   adb install build/app/outputs/flutter-apk/app-utility-profile.apk
   ```
   (`adb` is in `$ANDROID_HOME/platform-tools`.) Android stops asking after two denials, so use a fresh install for each take.
3. **The home screen.** Drag both apps (Retail Shop, orange bag; Utility Pay, navy bolt) next to each other on the home
   screen. Portrait, light theme, Do Not Disturb off, no other notifications in the shade.
4. **The terminal**, next to the emulator, in the project directory, with this ready (it is run in shot 8):
   ```bash
   adb exec-out screencap -p > /tmp/flag-secure.png && open /tmp/flag-secure.png
   ```
5. **Rehearse once.** The first payment on a fresh install also compiles shaders; the second run is the one to record.

## Shots

Times are targets. Every payment on the native service takes about 8 seconds. The scan always turns once all the way round
before the verdict: 2.4 s on Retail, 1.6 s on Utility.

| # | Time | Do | Must be visible | Say |
|---|---|---|---|---|
| 1 | 0:00 | Home screen. Hold on the two icons for a moment. | Retail Shop and Utility Pay side by side | One codebase, two Android apps, each with its own icon in its brand colors. |
| 2 | 0:15 | Open **Retail Shop**. Do nothing for three seconds. | the radar sweep goes round once, then the shield and "No root indicators found"; the summary and the Promo Banner; the app bar's SIMULATED badge is **absent** | The check is real, on the device. The scan is a CustomPainter; the verdict waits for one full revolution. |
| 3 | 0:50 | Tap the palette icon (**Switch brand**), choose **Utility Pay**. Wait for the animation, scroll the Bill Breakdown a little, then switch back to **Retail Shop**. | the theme animating: colors, corner radius, density, motion; the Bill Breakdown replacing the Promo Banner | Visual differences are tokens, structure is data. This switcher exists only outside release builds. |
| 4 | 1:20 | Tap **Pay**. Answer the notification prompt with **Allow**. | "Starting payment…", then "Processing your payment" with the percentage and bar | A foreground service runs the payment. The permission is requested through the bridge, and a denial would not stop the payment. |
| 5 | 1:40 | Pull the shade down at once and expand the card. Then press **Home** with the payment about half done. Keep the shade in view. | the notification "Processing your payment", its progress bar and its **Cancel** action; the bar keeps moving with the app in the background; finally "Payment complete" | Throttled to two updates a second, private on the lock screen, and the service keeps going in the background. |
| 6 | 2:10 | Tap the "Payment complete" notification. | the app opens on "Payment successful", the amount and a `TX-…` transaction id | The result came back from the native service through the event channel. |
| 7 | 2:25 | Tap **Repeat demo payment**, wait for the scan, tap **Pay**, pull the shade and tap **Cancel** in the notification. Reopen the app. | the notification disappears at once, and the app shows "Payment cancelled" and **Try again** | Cancel is the same transition whether it comes from the app or from the notification: a receiver that does not depend on the service being alive. |
| 8 | 2:55 | Open the page again (**Try again**) and wait for "No root indicators found". In the terminal, run the `screencap` command. Press **Recents** (`KEYCODE_APP_SWITCH` or the nav bar) and show the app's card. | Preview opens a **black image**; the Recents card is blank; the macOS recording still shows the page | `FLAG_SECURE` is on while the payment page is visible, in every mode. Android's own screenshot and the recents thumbnail are black. |
| 9 | 3:25 | Open **Utility Pay** from the home screen. Let the scan turn (quicker than Retail's), scroll the dense Bill Breakdown, tap **Pay**, answer **Allow** (it is a separate app), let it finish. | the faster, sharper scan; the compact list; the receipt with a euro amount | Same code, another brand: another look, rhythm and layout. |
| 10 | 4:05 | In Utility, open the demo panel (**Demo scenarios**, the tune icon). Under *Device security* choose **Simulated**, then **Rooted**. Close the panel. Reopen it and choose **Clean**. | the SIMULATED badge appears; "Payments are turned off because this device appears to be rooted."; Pay disabled; then "No root indicators found" again | Simulation replaces readings only; the secure window stays real. |
| 11 | 4:30 | Panel: switch on **Screen recording in progress**, close it. Then switch it off. | "Payment is paused while the screen is being recorded." with "This continues by itself when the recording stops."; Pay disabled; it lifts by itself | A recording blocks payment and lifts by itself when it ends. |
| 12 | 4:50 | Panel: switch **Screen protection available** off, close, tap **Check again** (it stays blocked). Switch it on and tap **Check again**. | "Screen protection could not be turned on, so payment is paused." and Check again; then "No root indicators found" | An unverifiable security control blocks payment. It is a reading: the real flag is untouched. |
| 13 | 5:10 | Panel: **Device check takes** → **15 s**; under *Display* switch **Performance overlay** on; close the panel. Watch the scan for a few turns. | the radar turning smoothly; the two performance graphs under the green line | The animation is one repaint layer and no widget rebuilds per frame. Numbers on an emulator are indicative. |
| 14 | 5:40 | Optional: panel → *Display* → overlay off; *Payment processing* → **Simulated**, then **Is declined**; close; **Pay**. | "The payment was declined." | Declines and failures are simulated scenarios; the native processing always succeeds. |
| 15 | 5:55 | Back to the home screen with the two icons. | the two apps | Release builds have none of these tools. The backend is simulated; native processing is a foreground service. |

## If something goes wrong

- **No notification prompt.** The app was installed over an earlier one that already answered it. Uninstall both, reinstall,
  and start the take again (shot 4 needs the prompt, shot 9 needs it again for the second app).
- **The payment finishes before the shade is open.** Pull the shade down *before* tapping Pay, then tap Pay.
- **`FLAG_SECURE` shot shows the page in Preview.** The page must be the visible window when `screencap` runs; do it on the
  review or processing page, not on the launcher or in the shade.
- **The verdict arrives at the end of a revolution, not instantly.** That is the dwell, not a hang: wait for it.
- **A recording of the emulator window is blank.** Grant the terminal or QuickTime screen-recording permission in macOS
  *System Settings > Privacy & Security > Screen Recording*.

## Evidence and limits

The exact validation results are in the [AI Insight Report](ai/AI_INSIGHT_REPORT.md). The one run on a physical phone
(2026-10-16, ZTE RedMagic 10 Pro, Android 16) and what it did not cover (the notification permission prompt, the lock screen,
Android versions other than 36, frame-timing numbers) are in [Manual QA](MANUAL_QA.md). On that phone the screen recording callback did not fire (the stock recorder on the emulator does trigger it), so the recording block is defense in depth and `FLAG_SECURE`, which blacks out the saved recording, is the control. An
emulator recording does not prove 120 Hz performance on a phone; the phone showed 120 FPS on the performance overlay, an
observation and not a measurement.

## Demo scenarios (debug and profile builds)

Whenever a device or backend is hard to put in a given state, every source with a platform side can run on a **simulation**.
The tune icon in the app bar opens a panel where, per source (device security, payment processing), you pick *Real* or
*Simulated* and, for a simulated one, play a situation:

- a clean, rooted, weakly-rooted or unverifiable device;
- a screen recording that starts and stops while the screen is open;
- how long the device check takes (1.5 s, 5 s, 15 s), to hold the scan on screen;
- a payment that succeeds, is declined, or fails while processing;
- a bill backend that goes offline (simulated by design: there is no backend).

A **SIMULATED** badge sits in the app bar while any source is simulated, in every build mode. The simulation replaces the
security *readings* only, never the window: `FLAG_SECURE` is applied through the real source in every mode. The panel's
*Display* section has Flutter's performance overlay and rolling build/raster statistics with Reset; reported display Hz is
not measured FPS. [Manual QA](MANUAL_QA.md#in-app-frame-statistics-without-adb-debugprofile) explains ADB-free phone measurements.
The app bar has the brand switcher. In Real mode the panel
shows a read-only **Device reports** block (the root signals that fired, whether a recording is detected, whether the
window is protected).

Release registry entries are selected with compile-time `kReleaseMode`/`appFlavor` conditions;
only that brand's demo catalog is supplied to the feature. Debug/profile retain all brands.
The artifact check is reproducible with `tool/check_release_brand_isolation.py`, which runs
`strings` on each AOT library and also scans decompressed APK entries for forbidden markers.
