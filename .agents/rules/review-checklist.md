---
trigger: model_decision
description: "Self-review and code-review checklist. Apply before declaring any task done, when asked to review/audit/refactor code (including AI-generated code), or when preparing the AI Insight Report."
---

# Review checklist

Run this against **your own output** before saying "done", and against any code you are asked to review. Report the result as a short list: ✅ checked / ⚠️ deviation and why / ❌ fixed. Don't just claim compliance — point to the file or line that shows it.

## Architecture
- [ ] Dependency rule holds: domain imports no Flutter, platform or data code; presentation does not import data; no DTOs above data.
- [ ] Each new class has a single reason to change. Files stay reasonably small (about 200–250 lines is a smell threshold; split by responsibility).
- [ ] New behaviour was **added** through an interface, registry or config, not by growing a `switch` or `if` chain (Open/Closed).
- [ ] Domain and data classes get dependencies through constructors and never see `Ref`. Providers only wire them. Presentation imports `di/` + `domain/`, never `data/`.
- [ ] Riverpod: no side effects in `build()`; `ref.mounted` checked after `await`; `ref.read` in callbacks, `ref.watch` only in `build`; `select` used for narrow rebuilds; no legacy providers; root retry disabled.
- [ ] Imports respect feature boundaries (only another feature's public domain barrel).

## Multi-tenant
- [ ] No brand, flavor or app-id checks outside `brand_registry.dart`.
- [ ] No hard-coded colors, radii, spacing or durations in `features/` or `core/` widgets: tokens only.
- [ ] New `ThemeExtension`s implement real `copyWith` + `lerp`.
- [ ] Adding a hypothetical brand #3 would need **zero** edits in `features/`.

## Correctness and safety
- [ ] Money is never `double`. Rounding and currency are explicit.
- [ ] All failure paths are mapped to typed `Failure`s and handled in the UI: a visible state, not a silent no-op.
- [ ] Security policy (rooted, recording) is enforced in domain and covered by tests.
- [ ] No sensitive data in logs. No `print`.
- [ ] Null-safety: no unjustified `!`, `late` or `dynamic`.

## Android native
- [ ] Every channel call replies once, on main. No blocking on main. Scopes and callbacks are released.
- [ ] API-level guards plus `@RequiresApi`. Permissions declared. No deprecated APIs.
- [ ] FGS: declared type and permission, user-initiated start, `START_NOT_STICKY`, correct stop, timeout handled, throttled notification updates.
- [ ] Dart and Kotlin channel constants and `docs/platform_channels.md` are in sync.

## Performance
- [ ] The animated painter uses `repaint:` + `RepaintBoundary`. No `setState` per frame. No avoidable allocations in `paint()`.
- [ ] Rebuild scope is minimal (`ref.watch(p.select(...))`, small `Consumer` leaves, `MediaQuery.*Of`, `const`).

## Tests and tooling
- [ ] New domain logic and notifiers have tests. The all-brands test passes.
- [ ] `dart format`, `flutter analyze` (zero issues) and `flutter test` are green. Both flavor builds work, once flavors exist.

## When reviewing AI-generated code (for the AI Insight Report)
Typical sub-optimal patterns to look for and call out explicitly:
- branding via `if/else`, or one giant theme class
- side effects in a provider's `build()` (re-run on rebuild or auto-retry), `ref.watch` inside callbacks, legacy `StateNotifier`
- `setState` driving an animation
- channel replies from background threads or replied twice
- `GlobalScope`
- a foreground service without a type, or started from the background
- `double` money
- business logic in widgets
- swallowed exceptions
- invented APIs or wrong API levels

When you find one, fix it, and append a short "AI suggestion → problem → correction" note to `docs/ai/PROMPT_LOG.md`.
