# AGENTS.md — Secure Payment Portal

Rules for any AI coding agent working in this repository (Antigravity, Cursor, Codex, Claude Code…).
They are always on. Topic rules in `.agents/rules/` hold the details — read the matching one **before** you start (see the index at the end).

## 1. Context

A senior-level Flutter test task: a **multi-tenant Payment Confirmation Module** built from one codebase.

- **Brands (flavors):** `retail` — Retail Shop (orange/gold, rounded, fluid motion, Promo Banner); `utility` — Utility Pay (navy/slate, dense, sharp edges, Bill Breakdown).
- **Android native (Kotlin):** root and screen-recording detection over a MethodChannel, `FLAG_SECURE` while the payment page is visible, and a Foreground Service with a progress notification that simulates payment processing.
- **Performance:** a math-driven "Security Scanning" `CustomPainter` animation at a steady 60/120 FPS that never repaints the rest of the tree.
- **Graded on:** how easy it is to add a 3rd or 4th brand, Android depth (service lifecycle, channel thread-safety, modern API compliance), UI fluidity, and Clean Architecture/SOLID quality.
- **Deliverables:** a clean repo, two flavor APKs, `docs/ai/AI_INSIGHT_REPORT.md` and `docs/ai/PROMPT_LOG.md`.

Backend: none. Payment APIs are simulated behind the same interfaces a real backend would use.

## 2. Stack (decided defaults — the developer may change them here, then follow the new choice)

| Concern | Choice |
|---|---|
| State management | `flutter_riverpod` 3.x without codegen: `Notifier`, `AsyncNotifier`, `Provider`, `StreamProvider`. Legacy `StateNotifier`, `StateProvider` and `ChangeNotifierProvider` are forbidden. |
| DI | Riverpod providers (no `get_it`). Composition root = root `ProviderScope(overrides: …)` in `main.dart`. |
| Equality / unions | Dart 3 `sealed` / `final` classes + `equatable` (no `freezed` unless asked) |
| Errors | `Result<T>` sealed type, `Success<T>(value)` or `Err<T>(Failure)`, from `lib/core/error/`. `Failure` is an abstract base in core with the generic failures; each feature declares its own `sealed` sub-hierarchy (`PaymentFailure`, `SecurityFailure`), so a `switch` is exhaustive per feature. |
| Native bridge | `MethodChannel` for commands, `EventChannel` for streams |
| Kotlin async | `kotlinx.coroutines` scoped to a lifecycle — never `GlobalScope` |
| Lints | `flutter_lints` + strict analyzer modes and extra rules, already configured in `analysis_options.yaml` |
| Testing | `flutter_test`, `mocktail` (dev only), `fake_async` (dev only, for time-based tests of pure Dart), `integration_test` (Flutter SDK package, dev only: frame timing on a device, run by hand with `flutter drive`, not part of `flutter test`), `ProviderContainer.test()` / `ProviderScope(overrides:)` |

Never add a package that is not in this table without asking first: name it, give a one-line reason, and offer an alternative that needs no package.

## 3. Architecture

### 3.1 The dependency rule (non-negotiable)

```
presentation ──▶ domain ◀── data
```

- **domain** is pure Dart. No `package:flutter`, no `dart:ui`, no `MethodChannel`, no JSON. It holds entities, value objects, repository **interfaces** and use cases.
- **data** implements domain interfaces. It owns DTOs, mappers, data sources (fake API, platform channel). It never leaks DTOs, `PlatformException` or any other exception upward: it maps them to domain `Failure`s.
- **presentation** holds widgets and Riverpod notifiers. It talks to a use case where one exists, otherwise straight to a repository interface (see the use-case rule below). There is no business logic in widgets.
- **di** (per feature) is the only place in a feature that touches both data and domain. Its providers construct data sources, repositories and use cases, and **expose them typed by domain interfaces**. Presentation imports `di/` + `domain/`, never `data/`.
- Features never know which brand they run in. They get theme tokens through `Theme` and their own config objects through a feature-owned provider that `app/` overrides.

### 3.2 Folder layout

```
lib/
  main.dart                 # bootstrap only: resolve brand → init DI → runApp
  app/                      # composition root: App widget, root ProviderScope overrides, routing
    brand/                  # BrandRegistry (the only reader of appFlavor), initial/active brand providers, themeProvider
    di/                     # root overrides: brand → feature config providers
    debug/                  # debug tooling: brand switcher, demo scenarios panel, SIMULATED badge
  brands/                   # the BrandConfig contract + one folder per tenant: pure configuration, no logic
    brand_config.dart       # BrandConfig: what a brand must declare
    retail/
    utility/
  core/                     # feature-agnostic and brand-agnostic
    design_system/          # ThemeExtension tokens + primitive widgets that read them
    error/                  # Result, Failure base + generic failures, data-layer exceptions, failureFromError
    async/                  # small stream helpers (ReplayLatest)
    logging/                # Logger (dart:developer behind an interface), loggerProvider; the only place that imports dart:developer
    format/                 # MoneyFormatter, DateTimeFormatter (no intl; not locale-aware)
    strings/                # AppStrings: every user-facing text, and the message for each failure key
    simulation/             # SourceMode: real or simulated, per controllable source
    platform/               # channel names, keys, error codes (mirror of Kotlin constants), WireReader for payloads
    domain/                 # shared value objects (Money, Currency…), pure Dart
  features/
    payment/{domain,data,di,presentation}/    # presentation/{config,sections,state,views,pages}/
    security/{domain,data,di,presentation}/
android/app/src/main/kotlin/<package>/
  MainActivity.kt           # wiring only
  security/  payment/  bridge/
android/brands.json              # the brands: id, display name, application id suffix; Gradle makes the flavors from it
integration_test/ test_driver/   # on-device frame timing of the security scan (flutter drive --profile)
tool/                            # make_launcher_icons.py (legacy icon PNGs), build_release_apks.sh (APKs into dist/)
.github/workflows/ci.yml         # format, analyze, tests, then a release APK per brand
```

Allowed imports:

- `core` imports nothing from `app`, `brands` or `features`.
- `features/x` may import `core` and the **public barrel** of another feature (`features/security/security.dart`: its domain, its `di/` providers typed by domain interfaces, and the `SecureScreen` widget). Another feature's `domain/` imports the pure-Dart `security_domain.dart` instead, so it never reaches Riverpod or `data/`. It never imports another feature's `data` or `presentation`.
- `brands` may import `core` and the features' public config types (`features/payment/payment.dart`: the config types, the page, the section registry and the simulation controls; `presentation/config/` holds the types a brand declares). It never imports `app`: `app` imports `brands`, never the other way round.
- Only a feature's own `di/` and `app/` import `data/` implementations. Only `app/` knows about flavors and concrete brands. Only `app/brand/brand_registry.dart` reads `appFlavor`.
- Imports are always `package:secure_payment_portal/...` (enforced by `always_use_package_imports`).

### 3.3 Layer rules

**Domain**
- Entities are immutable (`final` fields, `const` constructors, `Equatable`).
- Money is **never** `double`. Use a `Money` value object (integer minor units + currency code).
- Use cases follow the official Flutter architecture guide: add one only when the logic combines several repositories, is complex, or is reused (e.g. `ConfirmPayment` with the security policy). Otherwise a notifier calls a repository interface directly. No pass-through use cases that only forward to one repository method.
- A use case is one class with one public `call(...)` that returns `Future<Result<T>>` or `Stream<…>`.
- Security policy is business logic, so it lives in domain: for example "payment is blocked on a rooted device", or "a recording in progress cancels confirmation".
- Model uncertain platform facts as a tri-state: `detected`, `notDetected`, `unknown`. Do not collapse "can't tell" into `false`.

**Data**
- Name data sources by origin: `PaymentRemoteDataSource` (fake impl with deterministic delays), `SecurityPlatformDataSource` (channel).
- DTO → entity mapping lives in explicit mappers or `toEntity()`, never in the UI.
- Catch `PlatformException` and `MissingPluginException` (iOS has no native side) and map them to typed `Failure`s or `unknown` states.

**Presentation (Riverpod)**
- One `Notifier`/`AsyncNotifier` per screen or flow.
  - Multi-step flows use a `sealed` state class in a `Notifier`. The payment flow is: idle → securityCheck → ready → processing(progress) → success | failure.
  - Simple load-once data may use `AsyncValue`.
  - No nullable-flag soup like `isLoading` + `error` + `data`.
- Notifiers call use cases, or repository interfaces where no use case is warranted, obtained with `ref.watch` / `ref.read` from the feature's `di/`. They never call data sources directly.
- **Side effects live only in notifier methods, never in `build()`.** Riverpod 3 re-runs `build` on rebuilds and automatically retries failed builds, so a side effect there could start a payment twice.
  - The root `ProviderScope` disables retry globally (`retry: (_, __) => null`).
  - Enable retry per provider only for idempotent reads.
- After every `await` in a notifier, check `ref.mounted` before touching `state`.
- `ref.watch` belongs in `build` only. Use `ref.read` in callbacks and `ref.listen` for one-off effects (navigation, snackbars, haptics).
- Rebuild narrowly: `ref.watch(provider.select(...))` and small `ConsumerWidget`/`Consumer` leaves. Never watch a whole flow state at the page root "just in case".
- Screen-scoped providers are `autoDispose`. App-scoped ones (repositories, brand) stay alive.
- Widgets are small and `const` where possible. Split by responsibility (`*_page.dart` composes, `*_view.dart` renders).
- Domain and data classes never see `Ref`. They get dependencies through constructors, and providers only wire them.

### 3.4 Cross-cutting

- **Simulated sources:** a source with a platform side (security, payment processing) has a *real* slot (`realXDataSourceProvider`: the channel source once its native milestone is done; security and payment processing both are, so both run Real by default), a *simulated* slot (the fake) and a `SourceMode` provider. Real is the default once it exists; only a non-release build may switch. The fake implements a small **control interface** that lives in domain (`SecurityScenarioControl`, `PaymentScenarioControl`, `BillBackendControl`), and `di/` exposes it as a provider that is **null when a real source runs**. Debug tooling depends on those interfaces and the mode providers only: no `is Fake…`, no `Fake…` import outside `features/*/data` and `di/` (`test/architecture/layering_test.dart` checks it). A SIMULATED badge shows in every build while any source is simulated.

- **Errors:** `Failure` carries a user-safe message key, and expected errors are values (`Err`), never thrown across layers. Data sources throw typed `DataSourceException`s that stay inside the data layer: repositories catch them and map them with `failureFromError`. Streams never emit errors; an unreadable event becomes a state (`unknown`, `PaymentFailed`).
- **Logging:** use a `Logger` abstraction. Never use `print`. Never log amounts tied to an identity, card data, tokens or device fingerprints.
- **Strings:** user-facing text goes through one place (an l10n-ready `AppStrings`/ARB). Brand-specific copy belongs to the brand config.
- **SOLID in practice:** depend on interfaces at boundaries, keep classes small with one reason to change, and add a brand or section by **adding** code, not by editing `switch` statements (Open/Closed).

## 4. Golden rules per area (details in `.agents/rules/`)

1. **Multi-tenant:** no `if/else`, `switch` or ternary on brand, flavor or app id anywhere outside `lib/app/brand/brand_registry.dart`. Visual differences are tokens (`ThemeExtension`). Structural differences, like Promo Banner vs Bill Breakdown, are config-declared sections rendered through a registry.
2. **Native:** `MainActivity` only wires handlers. Every channel call replies **exactly once**, **on the main thread**, after any blocking work has run off it. Kotlin and Dart share channel names and error codes as mirrored constants.
3. **Performance:** an animation drives the painter through `CustomPainter(repaint: animation)` inside a `RepaintBoundary`. Never use `setState` per frame, and never allocate in `paint()` when that can be avoided.

## 5. How you work (agent workflow)

1. **Understand.** Restate the goal in 1–2 sentences and name the layer(s) and files involved. If the request conflicts with these rules, say so and propose the compliant alternative. Don't silently comply.
2. **Plan before code** when a change touches more than 2 files, any public contract (entity, repository interface, channel API, BrandConfig) or Gradle/Manifest. List the files to create or change, the layer of each, and the risks. Wait for approval.
3. **Implement in small steps.** One concern per change. Keep diffs reviewable. No drive-by refactors, no placeholder `TODO` implementations presented as done.
4. **Verify.** Don't invent APIs. For every Android API you use, state its minimum API level and guard it (`Build.VERSION.SDK_INT`, `@RequiresApi`). If you're unsure an API exists, say so instead of guessing.
5. **Self-review** against `.agents/rules/review-checklist.md` before saying "done", and report what you checked.
6. **Log.** After each significant task, append an entry to `docs/ai/PROMPT_LOG.md` using the template there. Be honest about weak spots or alternatives you rejected — that file feeds the AI Insight Report.
7. **Commit.** After each green step (format, analyze and tests pass) make a small commit with a Conventional Commits message (`feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`, `build:`) and propose that message to the developer. Never commit a red state. Never push or rewrite history without asking. Close each milestone with a commit that updates `docs/ai/PROMPT_LOG.md`.

Talk to the developer in the language they write in. Code, identifiers, comments, docs and commit messages are in English.

## 6. Definition of done

A task is done only when all of these pass (or you explain why one can't run):

```bash
dart format --set-exit-if-changed lib test
flutter analyze                       # zero issues, warnings included
flutter test
flutter build apk --debug --flavor retail
flutter build apk --debug --flavor utility
# native logic, when android/ changed (raw Gradle ignores `flutter config --jdk-dir`, so give it a JDK 21):
(cd android && JAVA_HOME="<path to JDK 21>" ./gradlew testDebugUnitTest)
```

New domain logic and notifiers come with tests (see `.agents/rules/testing.md`).

## 7. Never

- Hard-coded brand colors, radii or copy inside `features/` or `core/`. No `Colors.orange` in a payment widget.
- Business rules in widgets, or `BuildContext` in domain or data.
- `double` for money. `dynamic` without a reason. `!` on values that can really be null. Bare `catch (_) {}`.
- Legacy Riverpod providers (`StateNotifier`, `StateProvider`, `ChangeNotifierProvider`), `Ref` passed into domain or data classes, or global mutable singletons.
- Editing generated files: `*.g.dart`, `ios/Flutter/Generated.xcconfig`, `.dart_tool/`, `build/`, `local.properties`.
- Touching `ios/` unless asked. iOS must still compile, and channels degrade gracefully there.
- Deprecated Android APIs when a modern one exists, for example `stopForeground(true)` (use `ServiceCompat.stopForeground`) or a foreground service without `foregroundServiceType`.
- Committing secrets or keystores, or changing signing config.

## 8. Topic rules index (read before working on the topic)

| When you work on… | Read |
|---|---|
| brands, flavors, themes, ThemeExtension, brand-specific sections, adding a brand | `.agents/rules/multi-tenant-branding.md` |
| Kotlin, Gradle, AndroidManifest, MethodChannel/EventChannel (both sides), FLAG_SECURE, Foreground Service | `.agents/rules/android-native.md` |
| CustomPainter, animations, frame budget, rebuild/repaint optimisation | `.agents/rules/performance-custom-painter.md` |
| writing or changing tests | `.agents/rules/testing.md` |
| reviewing or refactoring code, or before declaring a task done | `.agents/rules/review-checklist.md` |
