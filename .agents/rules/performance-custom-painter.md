---
trigger: model_decision
description: "UI performance rules. Apply when writing or changing CustomPainter / Canvas code (the Security Scanning animation), AnimationController/Ticker usage, transitions, or when optimising rebuilds, repaints or frame times."
---

# High-performance UI ("Fluid Experience")

Target: the Security Scanning animation runs at the display's refresh rate (60/120 Hz) with **zero widget rebuilds per frame** and **no repaint outside its own layer**. Budget per frame: 16.6 ms at 60 Hz, 8.3 ms at 120 Hz, on both the UI and raster threads.

## 1. Architecture of an animated painter

```
SecurityScanIndicator (stateless: AnimatedSwitcher scan ⇄ verdict icon, one box for all states)
└── ScanAnimation (StatefulWidget, SingleTickerProviderStateMixin: owns the one ticker)
    └── Stack
        ├── RepaintBoundary ─ CustomPaint(ScanBackdropPainter, isComplex: true)   ← still layer
        └── RepaintBoundary ─ CustomPaint(                                         ← moving layer
              painter: SecurityScanPainter(
                animation: _controller,   ← receives the Animation itself
                style: ScanStyle.from(colors, motion),   ← tokens, resolved in didChangeDependencies
              ),
              willChange: true,           ← continuously animating: skip raster caching
            )
```
(`lib/core/design_system/scan/`. The painters are created again only when the brand's tokens change, never on a rebuild. Reduced motion parks the controller on a still pose and starts no ticker.)

- The painter extends `CustomPainter` with `super(repaint: animation)`. Each tick calls `markNeedsPaint` only, with **no `build`, no layout**. Never call `setState` per frame, and never wrap large subtrees in `AnimatedBuilder` (if you do need one, pass the static part as `child`).
- `shouldRepaint` compares only the static config (style/colors/params). The animation is handled by `repaint`.
- The `AnimationController` lives in the smallest possible `State`, is created in `initState` and disposed in `dispose`. Never use `Timer.periodic` for animation.
- Static decoration (grid, outer rings, labels) goes in a **separate** `CustomPaint` with its own `RepaintBoundary` beneath, in a `Stack`, so only the moving part repaints.
- Brand colors come from tokens, resolved in `build` and passed in as an immutable `ScanStyle`. The painter never touches `BuildContext` or `Theme`.

## 2. Math and smoothness

- Drive everything from **time**, not frame count: `t = animation.value` (0→1 over one period) and `phase = 2π·t`. The speed is then identical at 60 and 120 Hz.
- Make every looping function exactly periodic over the controller period (integer frequencies, `(t + k/n) % 1.0` for staggered pulses). `repeat()` then has no visible seam at the wrap.
- Easing comes from `Curves`/`brandMotion` tokens applied to `t`, not from ad-hoc math scattered around.
- Typical visuals:
  - **Radar sweep:** `canvas.save(); canvas.translate(c); canvas.rotate(phase)`, then draw with a `SweepGradient` shader that is **cached per size**. Don't rebuild the shader every frame.
  - **Pulses:** ring `i` has radius `((t + i/n) % 1) · rMax` and alpha `1 - that`. Mutate `paint.color` on a preallocated `Paint`.
  - **Sine wave:** sample about every 2–3 logical px, write into a preallocated `Float32List`, and draw with `drawRawPoints(PointMode.polygon, …)`, or reuse one `Path` with `reset()`.
- Document the math in a short comment block: formula, period, units. The reviewer will ask about it.

## 3. Allocation and expensive ops in `paint()`

- Preallocate `Paint` objects as `final` fields. Reuse `Path` objects. Cache size-dependent objects (shaders, static geometry) keyed by `Size` and recompute them only when the size changes.
- Avoid on every frame:
  - `saveLayer`, including the `Opacity` widget over animating content (use alpha in colors instead)
  - large-sigma `MaskFilter.blur`
  - `BackdropFilter`
  - `drawShadow`
  - complex anti-aliased `clipPath`
- For a glow, use a few concentric strokes with decreasing alpha, or a small blur sigma that you have measured.
- No `print` or logging inside `paint()`.

## 4. Rebuild discipline everywhere else

- `const` constructors wherever possible. Extract widgets into classes, not helper methods that return widgets.
- Use `MediaQuery.sizeOf(context)`, `paddingOf`, etc. instead of `MediaQuery.of(context)`, which rebuilds on any change.
- Use `ref.watch(provider.select(...))` and small `Consumer`/`ConsumerWidget` leaves. The scanning indicator must not rebuild when the payment state changes, unless its style changes. Riverpod 3 pauses listeners of invisible widgets (`TickerMode`); don't fight it with `keepAlive` hacks.
- Use `FadeTransition`, `SlideTransition` and `ScaleTransition` (no rebuilds) with brand motion tokens for screen transitions.
- Build long or dense lists (Bill Breakdown) lazily with `ListView.builder` + `itemExtent`/`prototypeItem`.
- Respect `MediaQuery.disableAnimationsOf(context)`: show a static or slowed scan for reduced-motion users.

## 5. High refresh rate (Android)

- Flutter renders at the device's active refresh rate. Some OEMs keep apps at 60 Hz unless the window requests a higher mode. If you add a native preferred-display-mode request, keep it in the native security/display module, guard it by API level, and measure before and after.

## 6. Proving it (required for this task)

- Profile on a real device: `flutter run --profile --flavor retail`. Use the DevTools Performance view and keep all frames under budget. Use `showPerformanceOverlay` for the demo video.
- In debug, check `debugRepaintRainbowEnabled = true`: only the scan layer should change color. Turn on "Track widget rebuilds" and confirm no rebuilds per frame.
- Add a widget test: pump the payment page, advance about 1 s of frames, and assert that a build counter on a sibling widget and on the page did **not** increase.
- Write the measured numbers (avg/worst frame build and raster time per brand) into `docs/ai/AI_INSIGHT_REPORT.md` when you finalise.

### How this repository proves it

- **Zero rebuilds:** `rebuiltDuring` (`test/helpers/rebuild_tracker.dart`, over `debugOnRebuildDirtyWidget`) around 60 frames of the scan returns an empty list.
- **Isolated repaints:** `RenderRepaintBoundary.debugAsymmetricPaintCount` of the moving layer rises once per frame, its `debugSymmetricPaintCount` and the still layer's and the page layer's counts do not move, and a probe `CustomPainter` next to the scan is not painted. (`debugOnProfilePaint` does not see a boundary repainting by itself; the boundary counters do.)
- **No allocation, no expensive ops:** a recording canvas (`TestRecordingCanvas`) shows only palette colours and no `saveLayer`, clip, shadow or blur; geometry and the sweep shader are built once (counters). A leaky `paint()` would also show as hundreds of new-generation GCs in the frame timing run.
- **Frame timing:** `integration_test/scan_performance_test.dart`, run with `flutter drive --profile --no-dds` (see its header). `--no-dds` is required: the test connects to the VM service itself.
- **Mutation checks:** remove a `RepaintBoundary`, add a `setState` per tick, make `shouldRepaint` always true, rebuild the shader per frame: each must fail a test.
