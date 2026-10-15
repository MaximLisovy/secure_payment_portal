import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';

NotifierProvider<SourceModeNotifier, SourceMode> _provider({
  required bool realWired,
  bool canSwitch = true,
}) => NotifierProvider<SourceModeNotifier, SourceMode>(
  () => SourceModeNotifier(
    isRealAvailable: (_) => realWired,
    canSwitch: canSwitch,
  ),
);

void main() {
  group('SourceModeNotifier', () {
    test('uses the real source when one is wired', () {
      final container = ProviderContainer.test();

      expect(container.read(_provider(realWired: true)), SourceMode.real);
    });

    test('falls back to the simulation when no real source is wired', () {
      final container = ProviderContainer.test();

      expect(container.read(_provider(realWired: false)), SourceMode.simulated);
    });

    test('can switch to the simulation and back when both exist', () {
      final provider = _provider(realWired: true);
      final container = ProviderContainer.test();

      container.read(provider.notifier).select(SourceMode.simulated);
      expect(container.read(provider), SourceMode.simulated);

      container.read(provider.notifier).select(SourceMode.real);
      expect(container.read(provider), SourceMode.real);
    });

    test('cannot switch to a real source that is not wired', () {
      final provider = _provider(realWired: false);
      final container = ProviderContainer.test();

      expect(
        () => container.read(provider.notifier).select(SourceMode.real),
        throwsStateError,
      );
      expect(container.read(provider), SourceMode.simulated);
    });

    test(
      'cannot switch at all when switching is off, as in a release build',
      () {
        final provider = _provider(realWired: true, canSwitch: false);
        final container = ProviderContainer.test();

        expect(
          () => container.read(provider.notifier).select(SourceMode.simulated),
          throwsStateError,
        );
        expect(container.read(provider), SourceMode.real);
      },
    );

    test('switching is on by default in a debug build', () {
      final notifier = SourceModeNotifier(isRealAvailable: (_) => true);

      expect(notifier.canSwitch, isTrue);
    });

    test('tells the app whether a real source exists', () {
      final wired = _provider(realWired: true);
      final unwired = _provider(realWired: false);
      final container = ProviderContainer.test();

      expect(container.read(wired.notifier).realAvailable, isTrue);
      expect(container.read(unwired.notifier).realAvailable, isFalse);
    });
  });
}
