---
trigger: model_decision
description: "Testing rules. Apply when writing, changing or running tests (Dart unit, Riverpod notifier/provider, widget, platform-channel tests, Kotlin JVM tests), or when adding domain logic or notifiers that need test coverage."
---

# Testing

Tests prove the architecture. Each layer is testable in isolation because it depends on interfaces. If something is hard to test, treat that as a design smell and fix the design, not the test.

## Layout

```
test/
  core/…                         mirrors lib/
  features/<x>/domain/…          use cases, policies, value objects
  features/<x>/data/…            repositories, mappers, platform data sources
  features/<x>/presentation/…    notifiers (ProviderContainer.test), widgets
  brands/all_brands_test.dart    renders key screens for EVERY registered brand
  helpers/                       pumpApp(brand:), fakes, builders
android/app/src/test/kotlin/…    JVM tests for pure Kotlin logic (RootDetector, checks)
```

## What must be tested

| Layer | Required |
|---|---|
| Domain | Every use case and policy: happy path, each failure type, edge cases. `Money` arithmetic and formatting. Pure Dart, no Flutter binding. |
| Data | Repository maps DTO → entity, and exceptions → the correct `Failure`. Platform data source uses `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(...)`, covering success, `PlatformException`, `MissingPluginException` → `unknown`, and malformed payloads. |
| Presentation | Each notifier through `ProviderContainer.test(overrides: [...])`, with the use-case (or repository) providers overridden by fakes or mocks. Record states with `container.listen(provider, (_, next) => states.add(next), fireImmediately: true)` and assert the sealed state sequence for success, failure and security-blocked flows. Key widgets: the correct section set per config, `SecureScreen` calling enable/disable on push/pop. |
| Brands | One parametrised test loops over `BrandRegistry.all` and pumps the payment page for each brand. It asserts the page renders, the required `ThemeExtension`s are registered, and the declared sections appear. Brand #3 is covered automatically. |
| Performance | A frame-pumping test that asserts no rebuilds of the page or a sibling widget during the scan animation (see the performance rules). |
| Kotlin | `RootDetector` with fake checks/filesystem. `SecureWindowController` ref-counting. Progress throttling logic. |

## Rules

- Arrange-Act-Assert, one behaviour per test, and descriptive names: `'emits [Processing, Success] when service completes'`.
- Use `mocktail` for interfaces. Prefer hand-written fakes for simple data sources, such as a fake payment API with configurable delay and outcome.
- No real timers or delays. In pure-Dart tests (fakes, repositories, notifiers, anything with a timer) use `fakeAsync` from `package:fake_async`: start the work with `unawaited(...)`, advance with `async.elapse(duration)` and `async.flushMicrotasks()`, and read a future's outcome with `FutureProbe` (`await` is not available inside it). Assert `expectNoPendingTimers(async)` where a timer could leak. Both helpers are in `test/helpers/fake_async_helpers.dart`. Use `testWidgets` and `tester.pump(duration)` only for widget tests. No flaky `Future.delayed` waits.
- Never test private implementation details. Test through public APIs and the states they emit.
- Widget tests wrap the subject in a helper, `pumpApp(widget, brand: …, overrides: …)`. It builds a `ProviderScope` with the brand override, the feature-config overrides and the test fakes, plus `ThemeData` + extensions. Don't repeat setup in every test.
- Override at the provider boundary: data sources and repositories in `di/`. Don't mock Riverpod itself.
- A platform data source has a **contract suite** (`test/features/<x>/data/<x>_platform_data_source_contract.dart`) that defines what any implementation must do. It runs against the fake and, later, against the channel-based source, which is what makes swapping them safe.
- `mocktail` needs `registerFallbackValue(...)` in `setUpAll` for every non-primitive argument matched with `any()`.
- Golden tests are optional. If you add them, make one per brand per key screen with fonts loaded, and keep them out of the default fast test run if they are platform-sensitive.

## Commands

```bash
flutter test                      # all Dart tests
flutter test --coverage           # optional coverage report
cd android && ./gradlew :app:testRetailDebugUnitTest   # Kotlin JVM tests (after flavors exist)
```
