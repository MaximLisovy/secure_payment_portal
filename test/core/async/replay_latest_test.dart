import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/async/replay_latest.dart';

void main() {
  group('ReplayLatest', () {
    test('replays the initial value to the first listener', () async {
      final source = ReplayLatest<int>(0);
      final seen = <int>[];

      final subscription = source.stream.listen(seen.add);
      await pumpEventQueue();

      expect(seen, [0]);
      await subscription.cancel();
    });

    test('replays only the latest value to a late listener', () async {
      final source = ReplayLatest<int>(0)
        ..add(1)
        ..add(2);
      final seen = <int>[];

      final subscription = source.stream.listen(seen.add);
      await pumpEventQueue();

      expect(seen, [2]);
      expect(source.latest, 2);
      await subscription.cancel();
    });

    test('delivers live updates after the replay, in order', () async {
      final source = ReplayLatest<int>(0);
      final seen = <int>[];
      final subscription = source.stream.listen(seen.add);

      source
        ..add(1)
        ..add(2);
      await pumpEventQueue();

      expect(seen, [0, 1, 2]);
      await subscription.cancel();
    });

    test('gives every listener its own replay', () async {
      final source = ReplayLatest<int>(0);
      final first = <int>[];
      final second = <int>[];
      final a = source.stream.listen(first.add);
      source.add(1);
      final b = source.stream.listen(second.add);
      await pumpEventQueue();

      expect(first, [0, 1]);
      expect(second, [1]);
      await a.cancel();
      await b.cancel();
    });

    test('stops delivering to a listener that cancelled', () async {
      final source = ReplayLatest<int>(0);
      final seen = <int>[];
      final subscription = source.stream.listen(seen.add);
      await pumpEventQueue();
      await subscription.cancel();

      source.add(1);
      await pumpEventQueue();

      expect(seen, [0]);
    });

    test('completes listeners on close, and ignores later values', () async {
      final source = ReplayLatest<int>(0);
      final seen = <int>[];
      var done = false;
      final subscription = source.stream.listen(
        seen.add,
        onDone: () => done = true,
      );

      await source.close();
      source.add(1);
      await pumpEventQueue();

      expect(done, isTrue);
      expect(seen, [0]);
      expect(source.latest, 0);
      await subscription.cancel();
    });

    test(
      'a listener added after close still gets the latest, then done',
      () async {
        final source = ReplayLatest<int>(7);
        await source.close();
        final seen = <int>[];
        var done = false;

        final subscription = source.stream.listen(
          seen.add,
          onDone: () => done = true,
        );
        await pumpEventQueue();

        expect(seen, [7]);
        expect(done, isTrue);
        await subscription.cancel();
      },
    );
  });
}
