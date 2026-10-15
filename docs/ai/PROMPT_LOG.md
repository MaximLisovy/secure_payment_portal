# AI Prompt Log

Key interactions with AI tools (Antigravity / Cursor / …) during this task.
The agent appends an entry after each significant task; the **Developer review**
part is written by me — that is where I show how I audited and refined the output.

---

## Template

### <NN>. <Short title> — <YYYY-MM-DD>
- **Tool / model:**
- **Goal:** what problem was being solved
- **Prompt (key part, verbatim):**
  > …
- **Context given:** rules / files / docs the agent relied on
- **AI output (summary):** what was produced, main design decisions
- **Assumptions & risks flagged by the agent:**
- **Developer review:** what I accepted, what I changed and why (sub-optimal parts, corrections)
- **Result:** files / commit

---

### 01. White-label foundation (Milestone 1) — 2026-10-15
- **Tool / model:** Claude Code, claude-sonnet-5-5
- **Goal:** Android flavors `retail`/`utility`, brand resolution from `appFlavor`, token `ThemeExtension`s with real `lerp`, one `ThemeFactory`, two brand configs and a token-only placeholder home, so adding brand #3 touches no feature code.
- **Prompt (key part, verbatim):**
  > Milestone 1 — foundation for the white-label engine. PLAN ONLY, no code yet. … Wait for my approval before writing code.
  >
  > Approved, with these decisions: A: move BrandConfig to lib/brands/brand_config.dart … D: an unknown flavor always throws; only a missing flavor falls back (non-release).
- **Context given:** `AGENTS.md`, `.agents/rules/multi-tenant-branding.md`, `review-checklist.md`, `testing.md`.
- **AI output (summary):** Plan first, then 7 steps. Four `ThemeExtension`s (`BrandColors/Shape/Density/Motion`) bundled in `BrandTokens`; `ThemeFactory.build(tokens, brightness:)` with an explicit `ColorScheme` and token-fed component themes; `BrandRegistry` is the only reader of `appFlavor`; `initialBrandProvider` → `activeBrandProvider` → `themeProvider`; a debug/profile brand switcher behind `!kReleaseMode`; a `brandOnSurface` role for brand-colored foregrounds. 80 tests; both flavor APKs built and run on an emulator.
- **Assumptions & risks flagged by the agent:**
  - The plan itself surfaced rule conflicts before any code: `BrandConfig` location (app↔brands cycle), `appFlavor` read in `main.dart` vs only in the registry, a redundant `themeData` field, `mocktail` not needed yet. All resolved in the rule files.
  - Environment: the only JDK was Temurin 25, which Kotlin Gradle plugin 2.2.20 cannot parse (`IllegalArgumentException: 25.0.1`); fixed with `flutter config --jdk-dir` pointing at JDK 21, documented in the README.
  - Found on a device screenshot, not by the tests, and fixed in this milestone: see the first correction below (Retail's vivid orange used as a foreground).
  - Rejected alternatives: `ColorScheme.fromSeed` (derives colors that are not tokens), a stored `themeData` on `BrandConfig` (two sources of truth), a `Map<Type, Object>` for feature configs (loses type safety), `ShapeBorder` fields in `BrandShape` (not always lerp-able).
- **Corrections made while building (AI suggestion → problem → correction):**
  - **One `primary` color for fills and foregrounds, checked by a contrast test of "on-color" pairs only** (primary/onPrimary, surface/onSurface…) → Material also uses `primary` as the foreground of text and outlined buttons, icons, the focus ring, the progress bar and the text cursor. Retail's vivid orange (#F57C00) is only 2.5–2.7:1 there (needs 4.5 for text, 3.0 for UI), and the test passed because it never looked at those pairs. Found by eyeballing an emulator screenshot → added a `brandOnSurface` role (Retail #C2410C, Utility reuses its navy), set every component foreground explicitly in `ComponentThemes`, and replaced the test with one table of 18 pairs (11 text at 4.5:1, 7 UI at 3:1) in `test/helpers/component_contrast_table.dart`. Each row reads its color from the built `ThemeData`, so a changed or unset component color is seen, not assumed. It runs for every registered brand, and a meta-test proves it flags the old Retail values.
    - Running the wider table on the old values found two more defects of the same class: the input border (`outline`) was 1.3:1 on Retail and 2.3:1 on Utility (now #94806A and #738299), and Utility's snackbar action (slate accent on a near-black bar) was 2.4:1, so the action now uses the text color.
  - The plan promised `.vscode/launch.json` (Q5 "include both") but the first pass never created it → noticed when re-reading the approved decisions; added debug and profile configs for both flavors.
  - Recalled `EquatableMixin` and `Override` from the main Riverpod barrel → equatable 3.0.0 has only `abstract mixin class Equatable`, and `Override` lives in `flutter_riverpod/misc.dart` → read the installed package source before writing code.
  - `LinearGradient.lerp(a, b, 0)` returns a gradient with explicit `stops`, so `lerp(0) == a` failed → `lerpGradient` returns the endpoint at t = 0 / 1.
  - Utility `controlHeight` was applied on top of `VisualDensity.compact` (-8dp), shrinking buttons twice → documented the order and set the value on purpose.
  - A test named "does not rebuild" passed even with `.select` removed (mutation check), because `ThemeData` equality already suppresses the emission → renamed it to what it really proves.
  - A theme test first asserted before `await container.pump()`, so it saw only the initial value → pump added.
- **Developer review:** _(to be written by the developer)_
- **Result:** Gradle flavors + manifest label; `lib/core/design_system/**`, `lib/brands/**`, `lib/app/**`; `test/**` (80 tests); `.vscode/launch.json`; README, AGENTS.md (use-case and git rules) and the multi-tenant rule file updated. Committed on `main`: one feature commit, then this log entry as the milestone-closing commit.

---

### 02. Milestone 1 follow-ups: accessible-by-default scheme, decorative outline, scaling notes — 2026-10-15
- **Tool / model:** Claude Code, claude-sonnet-5-5
- **Goal:** make unthemed Material widgets readable by default, give decorative borders their soft look back without weakening control borders, write down the later work without building it, and fix the git identity.
- **Prompt (key part, verbatim):**
  > map ColorScheme.primary to brandOnSurface (the accessible tone) and apply the vivid brandPrimary explicitly only where a fill is intended … Add a decorative outline role (mapped to ColorScheme.outlineVariant) for dividers and card borders. WCAG 1.4.11 exempts decorative borders, so leave it out of the 3:1 table and say so in a comment.
- **Context given:** `AGENTS.md`, `multi-tenant-branding.md`, the contrast table from entry 01.
- **AI output (summary):** `ColorScheme.primary` is now `brandOnSurface` and `onPrimary` reuses `surface`; fills stay explicit. New `outlineSubtle` role for card border, divider and progress track. Six more table rows for the `ColorScheme` defaults that unthemed widgets read, plus meta-tests (the old vivid Retail still fails; a soft outline used for a control fails). A "Scaling and later work" rule section and a scaling path in the insight report, both text only. Global git identity set and the existing commits re-authored. 83 tests; both flavor APKs built and checked on an emulator.
- **Assumptions & risks flagged by the agent:**
  - `onPrimary` reuses `surface` instead of a new token, because the table already requires `brandOnSurface` to hold 4.5:1 against every neutral surface and contrast is symmetric.
  - Observed on the device, not fixed: an unthemed Slider's inactive track is very faint on both brands (`surfaceContainerHighest` maps to `surfaceElevated`). The thumb and active track still carry the value. Fix when a feature needs a Slider: theme it explicitly with an inactive track from `outline` and add a table row.
  - The `ColorScheme` default is only a backstop for widgets nobody themed. Anything a feature actually uses should still be themed explicitly and get a table row.
- **Corrections made (AI suggestion → problem → correction):**
  - **Foregrounds patched one component at a time while `ColorScheme.primary` stayed the vivid fill** (my own fix in entry 01) → every widget nobody themed (Switch, Checkbox, Slider, focus, progress) still read the vivid color, so the trap stayed open for the next feature. The developer pointed it out → made the scheme the safe default (`primary` = accessible tone) and made the vivid fill the explicit, opt-in case; added table rows for the scheme defaults so that is enforced.
  - **One `outline` role for control borders and decorative borders** (entry 01 raised it to 3:1 for inputs) → Retail's card borders and dividers inherited the heavy tan and lost the soft look → split a decorative `outlineSubtle`, documented the WCAG 1.4.11 exemption in the table, and added a meta-test so the soft role cannot be used for a control without failing.
  - **Documentation drift:** adding `brandOnSurface` in entry 01 did not update the rule file's `BrandColors` row, which still listed the old roles → corrected together with this change, with a short "Color roles and contrast" rule.
- **Developer review:** _(to be written by the developer)_
- **Result:** commits `c0de752` (scheme), `5db62a4` (outlineSubtle), `21a2c0b` (docs), then this log entry. History re-authored to the configured identity.

---
