---
trigger: model_decision
description: "Multi-tenant / white-label rules. Apply when working on brands, flavors, appFlavor, ThemeData, ThemeExtension tokens, brand-specific UI (Promo Banner, Bill Breakdown), BrandConfig/BrandRegistry, or adding a new brand."
---

# Multi-tenant branding ("White-Label Engine")

The goal is that **adding a brand means adding files, not editing features**. The reviewer will ask "how do I add brand #3?" The honest answer must be: one folder in `lib/brands/`, one entry in the registry, one Gradle flavor and the assets. No other file changes.

## 1. Brand resolution: one decision, one place

- The flavor name **is** the brand id: `retail`, `utility`. It comes from Flutter's `appFlavor` (`package:flutter/services.dart`), which `--flavor` sets.
- `lib/app/brand/brand_registry.dart` is the **only** place that maps an id to a `BrandConfig`. It holds a `Map<String, BrandConfig Function()>` or a list. It is not a `switch` scattered around the code.
- **An unknown flavor always throws**, in every build mode, with a clear error naming the flavor and the registered ids. This catches a Gradle flavor that was added without a registry entry.
- **A missing flavor** (`appFlavor == null`: `flutter test`, iOS, a run without `--flavor`) falls back to one explicit default id kept in `brand_registry.dart`, but **only outside release**. In release (`kReleaseMode`) a missing flavor throws too.
- `brand_registry.dart` is the **only** file that reads `appFlavor`. It exposes `BrandRegistry.resolve({String? flavor = appFlavor, bool strict = kReleaseMode})`, so tests can pass the flavor and mode explicitly.
- `main.dart` calls the registry once (`BrandRegistry.standard.resolve()`) and passes the result into the root `ProviderScope` as `initialBrandProvider.overrideWithValue(brand)`. It never mentions `appFlavor` itself.
- `activeBrandProvider` (a `Notifier<BrandConfig>` in `app/brand/`) starts from `initialBrandProvider`. `themeProvider` derives `ThemeData` from it, and `MaterialApp(theme: ref.watch(themeProvider))` animates brand changes through the extensions' `lerp`.
- A brand switcher, for the demo video, may call `activeBrandProvider.notifier.select(id)`. It is mounted from the composition root only, behind `!kReleaseMode` (so it works in debug and profile, and is tree-shaken from release). It lists `registry.all` generically and never branches on a brand.

## 2. What a brand is made of

```
BrandConfig (immutable, lib/brands/brand_config.dart)
├── id, displayName
├── tokens: BrandTokens            → ThemeExtension(s) in core/design_system
├── featureConfigs                 → typed configs owned by features, e.g. PaymentScreenConfig (added with each feature)
└── assets: BrandAssets            → paths under assets/brands/<id>/ (added with the polish milestone, not before)
```

`BrandConfig` lives in `brands/` (not `app/`) so that `brands → app` is never needed: `app` imports `brands`, never the reverse.

There is **no `themeData` field**. `ThemeData` is derived data: `themeProvider` builds it from `tokens` with the one shared `ThemeFactory`, so it is never hand-written per brand and never stored twice.

Light theme only for now. Keep tokens and `ThemeFactory` brightness-agnostic (the factory takes the brightness explicitly), so a dark token set can be added later as a second `BrandTokens` per brand without touching any widget.

### Tokens (visual differences)

Put every visual difference into `ThemeExtension` subclasses in `lib/core/design_system/`. Split them by concern so each stays small:

| Extension | Examples |
|---|---|
| `BrandColors` | semantic roles only: `brandPrimary` (fills), `brandOnSurface` (the brand as a foreground), `brandAccent`, `outline` (control edges) and `outlineSubtle` (decorative edges), `surfaceElevated`, `success`, `danger`, `scanGlow`, gradients. Names describe **role**, never hue (`orange` is a forbidden token name). |
| `BrandShape` | `radiusSm/Md/Lg`, `buttonShape`, `cardBorder`. Retail is rounded, Utility is sharp: the difference is only in the values. |
| `BrandDensity` | spacing scale, `VisualDensity`, list row height. Utility is high-density. |
| `BrandMotion` | durations, curves, page-transition builder. Retail is fluid, Utility is crisp. |
| `BrandTypography` (optional) | font family or weights, if brands differ |

Every extension must:
- implement `copyWith` **and** a correct `lerp`, so a theme switch animates instead of snapping. Use `Color.lerp`, `lerpDouble`, `VisualDensity.lerp` and `Gradient.lerp`. Store shapes as numeric radii, not `ShapeBorder`s, so `lerp` is always valid.
- document members that cannot be interpolated (`Curve`, `PageTransitionsTheme`): they switch at `t >= 0.5`.
- be read through a typed accessor such as `context.brandColors`, an extension on `BuildContext` that asserts the extension is registered.
- have no defaults that hide a missing registration. A missing token is a bug and must surface in debug.

`ThemeFactory.build(BrandTokens)` creates `ThemeData` (`ColorScheme`, component themes, extensions) for **all** brands. Material component themes (`FilledButtonThemeData`, `CardThemeData`, `InputDecorationTheme`…) take their values from tokens, so plain Material widgets are on-brand automatically.

#### Color roles and contrast

- `ColorScheme.primary` is `brandOnSurface`, the accessible brand foreground, because Material reads `primary` as a foreground far more often than as a fill. Widgets nobody themed (Switch, Checkbox, Slider…) are then readable by default.
- The vivid `brandPrimary` is applied **explicitly**, only where a fill is intended (FilledButton, AppBar…), in `ComponentThemes`. It never goes through the scheme.
- `outline` is for edges that identify a control (input border, outlined button) and holds 3:1. `outlineSubtle` (`ColorScheme.outlineVariant`) is for purely decorative edges (card border, divider, progress track); WCAG 1.4.11 exempts those, so it is left out of the contrast table.
- Every color that `ComponentThemes` sets, and every `ColorScheme` default that unthemed widgets read, has a row in the one table `test/helpers/component_contrast_table.dart`: **4.5:1 for text, 3:1 for non-text UI**. Rows read the built `ThemeData`, and the table runs for every registered brand. Adding a themed color means adding a row.

### Feature configs (structural differences)

The Promo Banner (Retail) and the Bill Breakdown (Utility) are **not** `if (brand == retail)`. They are also not a growing set of `bool showX` flags.

- The payment feature owns `PaymentScreenConfig` with an ordered `List<PaymentSectionSpec>`, plus any section-specific data such as promo copy.
- The payment presentation layer owns a `PaymentSectionRegistry`, an immutable map **keyed by the spec's type** (`registry.adding<BillBreakdownSpec>((context, spec) => …)`). `PaymentSectionSpec` is an open class, not a sealed one or an enum, so a new section type is a new subclass and needs no `switch` to edit. A spec nobody registered fails loudly (`StateError` naming it); it is never skipped.
- A section builder returns a **sliver**, so the page lays every section out in one lazy `CustomScrollView` (the Bill Breakdown is a `SliverFixedExtentList` with the brand's `rowHeight`). Wrap box content in a `SliverToBoxAdapter`.
- The payment page renders `config.sections` through the registry. It has no knowledge of brands.
- A brand declares its layout, for example `[summary, promoBanner]` vs `[summary, billBreakdown]`. The pay action is **not** a section: it is pinned below the scroll view on every brand, so it is always in reach.
- A new section type = a new spec subclass + a widget + one `.adding` entry in `PaymentSectionRegistry.standard()` (+ an export in `payment.dart` for the spec). A new brand that reuses existing sections touches nothing in `features/`.

Each feature **declares** its own config provider and `app/` **overrides** it. A feature never imports `lib/brands/` or `BrandConfig`.

```dart
// features/payment/di/payment_providers.dart
final paymentScreenConfigProvider = Provider<PaymentScreenConfig>(
  (ref) => throw UnimplementedError('Overridden in app/di'),
);

// app/di/root_overrides.dart
paymentScreenConfigProvider.overrideWith(
  (ref) => ref.watch(activeBrandProvider).payment,
),
```

ThemeExtensions (tokens) + Riverpod overrides (config, built on `InheritedWidget` under the hood) are this project's answer to the task's "ThemeExtensions, InheritedWidget, or a similar scalable pattern". State that explicitly in the AI Insight Report.

## 3. Android flavors

- `android/brands.json` lists the brands: `id`, `displayName` and `applicationIdSuffix` (always `.<id>`). `android/app/build.gradle.kts` reads it and creates one product flavor per entry in a loop (`dimension = "brand"`, the suffix, and `resValue("string", "app_name", displayName)`), and fails the configuration with a readable message for a duplicate or malformed entry. It holds no brand by name. `test/brands/brands_manifest_test.dart` checks the manifest against `BrandRegistry`: same ids, same display names, suffix `.<id>`.
- `AndroidManifest.xml` uses `android:label="@string/app_name"`.
- Per-brand launcher icons go in `android/app/src/<id>/res/mipmap-*`. Per-brand Dart assets go in `assets/brands/<id>/`, declared in `pubspec.yaml`.
- Native code is brand-agnostic too. If Kotlin ever needs brand data, such as the notification accent color, pass it from Dart as config or as a flavor `resValue`. Never branch on the flavor in Kotlin.
- iOS flavors are out of scope unless the developer asks.

## 4. Checklist: add a new brand

1. `lib/brands/<id>/<id>_brand.dart` — a `const BrandConfig` with tokens + feature configs (+ assets once `BrandAssets` exists). Configuration only.
2. Register it in `brand_registry.dart` — one import and one list entry.
3. One entry in `android/brands.json` (`id`, `displayName`, `applicationIdSuffix`: `.<id>`). The flavor name must equal the brand id. Gradle needs no edit.
4. Once `BrandAssets` exists: `assets/brands/<id>/` + `pubspec.yaml` asset entry.
5. Nothing in `features/` or `core/` changes. If something has to, the abstraction is leaking: stop and propose a fix to the abstraction first.
6. The "all brands" tests pick the new brand up automatically through the registry: the real payment page renders its bill, every section it declares has a widget, rows have its row height, and a payment goes through to the receipt.

## 5. Red flags (refuse or fix)

- `appFlavor`, `brand.id ==`, `isRetail`, `if (brand…)` or `switch (brandId)` outside the registry.
- Hex colors, `Colors.*`, `BorderRadius.circular(12)` literals or magic spacing numbers in feature widgets. Use tokens.
- One mega `BrandTheme` class with 60 fields. Split by concern.
- A `ThemeExtension` without a real `lerp` (`return this`).
- Brand-specific widgets living in `brands/`. Brands are config; widgets live in features or `core/design_system`.

## 6. Scaling and later work

Planned for the final milestone. **Do not implement any of it earlier.** Until then the checklist in §4 applies unchanged.

1. **Brands manifest.** One `android/brands.json` with `id`, `displayName` and `applicationIdSuffix` per brand. Gradle reads it and creates the `productFlavors` in a loop, so adding a brand no longer touches Gradle code. Step 3 of the §4 checklist then becomes one manifest entry.
2. **Manifest and registry stay in sync.** A test checks that `android/brands.json` and `BrandRegistry` list the same ids and display names. It closes the duplication of the display name between Gradle and `BrandConfig`.
3. **CI.** A GitHub Actions matrix builds and tests every flavor. The flavor list comes from the same manifest, and the JDK comes from `setup-java` (21, see the README).
4. **Per-flavor launcher icons** in `android/app/src/<id>/res/mipmap-*`.
