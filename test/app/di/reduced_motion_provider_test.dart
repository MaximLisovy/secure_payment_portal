import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/di/reduced_motion_provider.dart';

void main() {
  testWidgets('follows the platform setting while it is watched', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final container = ProviderContainer.test();
    final seen = <bool>[];
    container.listen(
      reducedMotionProvider,
      (_, next) => seen.add(next),
      fireImmediately: true,
    );
    expect(seen, [false]);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    expect(container.read(reducedMotionProvider), isTrue);

    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    expect(container.read(reducedMotionProvider), isFalse);
    expect(seen, [false, true, false]);
  });

  testWidgets('starts from the setting as it is', (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    final container = ProviderContainer.test();
    expect(container.read(reducedMotionProvider), isTrue);
  });

  testWidgets('stops listening when its scope is gone', (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final container = ProviderContainer.test();
    container.read(reducedMotionProvider);
    container.dispose();

    expect(
      () => tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true),
      returnsNormally,
    );
  });
}
