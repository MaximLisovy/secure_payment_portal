# Appendix A: Performance evidence

Part of the [AI Insight Report](../AI_INSIGHT_REPORT.md). Numbers are from a Pixel_9 **emulator** (60 Hz). On a phone (ZTE RedMagic 10 Pro, Android 16) the performance overlay showed 120 FPS with no visible drops; the harness was not run there, so there are no phone numbers ([Manual QA](../../MANUAL_QA.md)).


The security scan is a `CustomPainter` radar (a sweep and three staggered pulses) in `lib/core/design_system/scan/`. The goal: the display's own refresh rate, no widget rebuilt per frame, and nothing repainted outside the scan's own layer.

**What makes it cheap, and how each claim is checked.**

| Claim | How it is checked |
|---|---|
| No widget rebuilds while the scan runs | a test pumps 60 frames and asserts that `debugOnRebuildDirtyWidget` fired for nothing, for the primitive and for the whole security card |
| Only the moving layer repaints | the repaint boundary's own counters: the moving layer's asymmetric paint count rises once per frame, its symmetric count and the counts of the still layer and of the page layer do not move; a probe painter beside the scan is never painted. Removing the boundary, or adding a `setState` per tick, makes these tests fail (both were tried) |
| Speed does not depend on the frame rate | the phase is elapsed time over the period: 600 ms of a 2.4 s period gives 0.25 at 120, 50 and 10 frames per second |
| The loop has no seam | the maths is periodic by construction (documented in `scan_math.dart`) and tested: the sweep turns by exactly 2π per period, and every pulse is invisible on both sides of the wrap |
| `paint()` allocates nothing | the paints are fields, colours come from a palette built once per style, the sweep shader is built once, geometry once per size (counters in tests); no `saveLayer`, clip, blur or shadow (asserted on a recording canvas). The frame timing run adds the garbage collection count as a check |
| The ticker lives exactly as long as the scan | `transientCallbackCount` is 0 once the verdict is shown, after the page is left, and with reduced motion |

I ran mutation checks on the maths, the painters, the widget, the flow and the summary tool (change the code, see a test fail). Four mutants first survived and each got a test (the fractional part of a negative number, a painter rebuilt when only the reduced-motion setting changes, a timer left running after the page was left, a box whose size was read from the constant under test); one is left, and it is equivalent (it changes a condition that can never be true in the state it guards).

**Frame timing.** `integration_test/scan_performance_test.dart`, `flutter drive --profile --no-dds`, every registered brand, each measured three times for 8 s after a 2 s warm-up, and the median reported. Four variants per brand: the real app with the scan running (`scan-in-app`), the scan alone on an empty page (`scan-alone`), Material's own `CircularProgressIndicator` alone on an empty page (`spinner-alone`, what a stock animated widget costs), and a layer that draws one dot per frame (`floor-alone`, the least any animating layer costs on this device, which the emulator needed to be read at all).

| Brand | Variant | FPS | Build (ms): avg / p90 / worst | Raster (ms): avg / p90 / worst | Frames over 16.67 ms (build / raster) | New-gen GCs |
|---|---|---|---|---|---|---|
| retail | floor-alone | 59.9 | 1.08 / 1.71 / 8.66 | 13.60 / 19.52 / 53.30 | 0 / 149 | 2 |
| retail | **scan-alone** | 59.4 | 1.07 / 1.83 / 6.04 | 13.69 / 19.26 / 28.41 | 0 / 155 | 2 |
| retail | **scan-in-app** | 60.3 | 1.15 / 1.84 / 6.92 | 15.98 / 19.58 / 54.06 | 0 / 212 | 2 |
| retail | spinner-alone | 59.9 | 1.41 / 2.15 / 7.22 | 14.87 / 19.26 / 33.91 | 0 / 187 | 6 |
| utility | floor-alone | 59.9 | 0.92 / 1.46 / 6.42 | 16.41 / 19.13 / 28.33 | 0 / 210 | 2 |
| utility | **scan-alone** | 59.9 | 1.12 / 1.80 / 10.44 | 15.20 / 19.74 / 39.05 | 0 / 190 | 2 |
| utility | **scan-in-app** | 59.1 | 1.18 / 1.97 / 10.51 | 16.39 / 19.55 / 73.83 | 0 / 211 | 2 |
| utility | spinner-alone | 59.4 | 1.40 / 2.32 / 10.07 | 16.34 / 19.18 / 59.12 | 0 / 194 | 6 |

Pixel_9 emulator (Android 16, API 36, arm64, host GPU), **profile build**, 60 Hz display, 8 s recorded per run, median of 3 runs. `floor-alone` is a layer that repaints every frame and draws one dot: the least an animating layer can cost on this device.

What the numbers say, and what they do not:

- **UI thread.** The scan costs 1.07 to 1.18 ms per frame on average (p90 under 2 ms), against 0.92 to 1.08 ms for the one-dot floor and 1.40 ms for Material's own spinner. It adds about 0.1 to 0.2 ms to the least possible, and is cheaper than a stock widget. No frame went over the 16.67 ms budget on the UI thread in any run.
- **Allocation.** Two new-generation garbage collections in 8 s, the same as the floor, against six for the spinner (twelve in an earlier run of the same harness without the floor). `paint()` does not allocate in any way a collector would notice.
- **Steady rate.** 59.1 to 60.3 frames per second delivered for every variant, on a 60 Hz display.
- **Raster time on the emulator tells nothing about the scan.** The floor, one dot per frame, takes 13.6 and 16.4 ms to rasterise on average, and about 150 to 210 of its roughly 480 frames are over budget, the same as the scan and the spinner. The emulator's host-GPU swap path sets that floor, not the drawing. The honest reading is that the scan adds nothing measurable on top of it, not that rasterising is cheap on a phone. For the same reason the 30 to 75 ms worst frames, which every variant has including the floor, are emulator hitches and not the scan.
- **Noise.** Run to run, and brand to brand for the identical floor, raster averages move by about 3 ms, so differences under that are not differences. A first complete run (without the floor) gave the same picture: scan 1.02 to 1.16 ms on the UI thread, 2 to 4 collections, the spinner 12.
- **Observed on a phone, not measured.** 120 FPS on the performance overlay, no visible drops, on a ZTE RedMagic 10 Pro (`M6-7`, qualitative). **Not claimed:** any frame-timing number for 90 or 120 Hz or a real GPU (the harness, `M6-6`, was not run on the phone), and anything about thermal behaviour or a low-power mode (`M6-9`, `M6-10`, not tested).


**Unchanged verdict timing.** The flow reveals the verdict at the end of a scan revolution: at least one period,
aligned to the current revolution, with the existing reduced-motion and final-confirmation exceptions. VerdictHold was not
changed by the review fixes. The decision and its trade-offs remain in [working log entry 08](working_log.md#08-the-security-scanning-animation-milestone-6--2026-10-16).


## Phone frame statistics

The debug/profile demo panel now collects SchedulerBinding frame timings without ADB. It uses a rolling 600-frame window,
nearest-rank percentiles and independent build/raster distributions; Reset clears samples and count. Values update once per
second in a small leaf, with no per-frame provider publication. Collection continues with the panel closed. These are whole-app
measurements (including panel transitions), separate from the isolated on-device scan harness above. The display field reports
Hz and does not measure FPS. See the [manual steps](../../MANUAL_QA.md#in-app-frame-statistics-without-adb-debugprofile).

| Phone / OS | Flavor / scenario | Display Hz | Frames / window | Build p50 / p90 / p99 / worst (ms) | Raster p50 / p90 / p99 / worst (ms) |
|---|---|---|---|---|---|
| ZTE RedMagic 10 Pro / Android 16 | retail profile | not measured | not measured | not measured | not measured |
| ZTE RedMagic 10 Pro / Android 16 | utility profile | not measured | not measured | not measured | not measured |

These rows are placeholders for the developer's measurements. The earlier visual observation of 120 Hz is unchanged and
is not substituted for timing data from this new readout.
