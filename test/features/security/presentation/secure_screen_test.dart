import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/features/security/data/datasources/fake_security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';
import 'package:secure_payment_portal/features/security/security.dart';

import '../helpers/gated_secure_window_controller.dart';

Future<FakeSecurityPlatformDataSource> _pump(
  WidgetTester tester,
  Widget home, {
  FakeSecurityPlatformDataSource? fake,
}) async {
  final source = fake ?? FakeSecurityPlatformDataSource();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        realSecurityPlatformDataSourceProvider.overrideWithValue(source),
      ],
      child: MaterialApp(home: home),
    ),
  );
  await tester.pump();
  return source;
}

const _secureText = SecureScreen(child: Text('secure'));

/// A route with a button that pushes [next].
Widget _withPushButton(Widget next) => Builder(
  builder: (context) => TextButton(
    onPressed: () => Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => next)),
    child: const Text('push'),
  ),
);

void main() {
  group('SecureScreen', () {
    testWidgets('protects the window while it is on screen', (tester) async {
      final fake = await _pump(tester, _secureText);

      expect(fake.secureWindowCount, 1);
      expect(find.text('secure'), findsOneWidget);
    });

    // The request must leave in `initState`, before the first frame goes to the
    // engine; the state may not change there, because Riverpod forbids it.
    testWidgets('asks at once, and shows pending until the platform answers', (
      tester,
    ) async {
      final gate = GatedSecureWindowController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [secureWindowControllerProvider.overrideWithValue(gate)],
          child: const MaterialApp(home: _secureText),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SecureScreen)),
      );

      expect(tester.takeException(), isNull);
      expect(gate.enables, 1);
      await tester.pump();
      expect(container.read(secureWindowProvider), const SecureWindowPending());

      gate.answer.complete(Success.unit);
      await tester.pump();
      expect(
        container.read(secureWindowProvider),
        const SecureWindowProtected(),
      );
    });

    testWidgets('releases the window when it leaves the tree', (tester) async {
      final fake = await _pump(tester, _secureText);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            realSecurityPlatformDataSourceProvider.overrideWithValue(fake),
          ],
          child: const MaterialApp(home: Text('plain')),
        ),
      );
      await tester.pump();

      expect(fake.secureWindowCount, 0);
    });

    testWidgets('a pushed secure route protects, and popping it releases', (
      tester,
    ) async {
      final fake = await _pump(tester, _withPushButton(_secureText));
      expect(
        fake.secureWindowCount,
        0,
        reason: 'the first route is not secure',
      );

      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();
      expect(fake.secureWindowCount, 1);

      Navigator.of(tester.element(find.text('secure'))).pop();
      await tester.pumpAndSettle();
      expect(fake.secureWindowCount, 0);
    });

    testWidgets('stays protected through the whole pop animation', (
      tester,
    ) async {
      final fake = await _pump(tester, _withPushButton(_secureText));
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.text('secure'))).pop();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.text('secure'),
        findsOneWidget,
        reason: 'still animating out',
      );
      expect(fake.secureWindowCount, 1, reason: 'visible, so protected');
    });

    testWidgets('stays protected while another route is pushed over it', (
      tester,
    ) async {
      final inner = Builder(
        builder: (context) => SecureScreen(
          child: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const Text('on top')),
            ),
            child: const Text('cover'),
          ),
        ),
      );
      final fake = await _pump(tester, inner);
      final counts = <int>[];

      await tester.tap(find.text('cover'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        counts.add(fake.secureWindowCount);
      }
      await tester.pumpAndSettle();

      expect(
        counts,
        everyElement(1),
        reason: 'never unprotected mid-transition',
      );
      expect(fake.secureWindowCount, 1);
    });

    testWidgets('two secure screens share one protection and never drop it', (
      tester,
    ) async {
      const second = SecureScreen(child: Text('second'));
      final first = SecureScreen(child: _withPushButton(second));
      final fake = await _pump(tester, first);
      final counts = <int>[fake.secureWindowCount];

      await tester.tap(find.text('push'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        counts.add(fake.secureWindowCount);
      }
      await tester.pumpAndSettle();

      expect(counts, everyElement(1), reason: 'one native enable, no gap');

      Navigator.of(tester.element(find.text('second'))).pop();
      await tester.pumpAndSettle();
      expect(
        fake.secureWindowCount,
        1,
        reason: 'the first screen still needs it',
      );
    });

    testWidgets(
      'a device that cannot protect its window shows as failed, and recovers on retry',
      (tester) async {
        final fake = FakeSecurityPlatformDataSource()
          ..setScreenProtectionAvailable(available: false);
        await _pump(tester, _secureText, fake: fake);
        final container = ProviderScope.containerOf(
          tester.element(find.text('secure')),
        );

        expect(container.read(secureWindowProvider), isA<SecureWindowFailed>());
        expect(fake.secureWindowCount, 0);

        fake.setScreenProtectionAvailable(available: true);
        await container.read(secureWindowProvider.notifier).retry();

        expect(
          container.read(secureWindowProvider),
          const SecureWindowProtected(),
        );
        expect(fake.secureWindowCount, 1);
      },
    );
  });
}
