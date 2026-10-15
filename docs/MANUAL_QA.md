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

## Devices

| Phone model | Android version / API level | Build | Date |
|---|---|---|---|
| | | | |
