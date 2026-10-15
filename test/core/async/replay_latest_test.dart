import 'dart:async';

import 'package:fake_async/fake_async.dart';
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

  // Regression guard: code built on a Stream.multi, or on nested forwarding,
  // loses the done event and never completes cancel() under a fake clock.
  group('ReplayLatest under a fake clock', () {
    test('delivers the replay and later values in order', () {
      fakeAsync((async) {
        final source = ReplayLatest<int>(0)..add(1);
        final seen = <int>[];
        source.stream.listen(seen.add);
        async.flushMicrotasks();

        source
          ..add(2)
          ..add(3);
        async.flushMicrotasks();

        expect(seen, [1, 2, 3]);
      });
    });

    test('tells every listener the stream is done on close', () {
      fakeAsync((async) {
        final source = ReplayLatest<int>(0);
        var firstDone = false;
        var secondDone = false;
        source.stream.listen((_) {}, onDone: () => firstDone = true);
        source.stream.listen((_) {}, onDone: () => secondDone = true);
        async.flushMicrotasks();

        unawaited(source.close());
        async.flushMicrotasks();

        expect(firstDone, isTrue);
        expect(secondDone, isTrue);
      });
    });

    test('cancelling a subscription completes, and stops delivery', () {
      fakeAsync((async) {
        final source = ReplayLatest<int>(0);
        final seen = <int>[];
        final subscription = source.stream.listen(seen.add);
        async.flushMicrotasks();
        var cancelled = false;

        unawaited(subscription.cancel().then((_) => cancelled = true));
        async.flushMicrotasks();
        source.add(1);
        async.flushMicrotasks();

        expect(cancelled, isTrue);
        expect(seen, [0]);
      });
    });

    test('close completes and leaves nothing pending', () {
      fakeAsync((async) {
        final source = ReplayLatest<int>(0);
        source.stream.listen((_) {});
        async.flushMicrotasks();
        var closed = false;

        unawaited(source.close().then((_) => closed = true));
        async.flushMicrotasks();

        expect(closed, isTrue);
        expect(async.nonPeriodicTimerCount, 0);
        expect(async.periodicTimerCount, 0);
      });
    });
  });

  group('ReplayLatest.empty', () {
    test('replays nothing until the upstream speaks', () async {
      final source = ReplayLatest<int>.empty();
      final seen = <int>[];

      final subscription = source.stream.listen(seen.add);
      await pumpEventQueue();
      expect(seen, isEmpty);
      expect(source.hasValue, isFalse);

      source.add(1);
      await pumpEventQueue();
      expect(seen, [1]);
      expect(source.hasValue, isTrue);
      await subscription.cancel();
    });

    test('replays the latest value to a listener that joins after', () async {
      final source = ReplayLatest<int>.empty()..add(5);
      final seen = <int>[];

      final subscription = source.stream.listen(seen.add);
      await pumpEventQueue();

      expect(seen, [5]);
      await subscription.cancel();
    });

    test('has no latest value to read before the first add', () {
      expect(() => ReplayLatest<int>.empty().latest, throwsStateError);
      expect(ReplayLatest<int>(3).latest, 3);
    });
  });

  group('ReplayLatest listener hooks', () {
    late int opened;
    late int closed;
    late ReplayLatest<int> source;

    ReplayLatest<int> create({bool forget = false}) => ReplayLatest<int>.empty(
      onFirstListener: () => opened++,
      onLastCancel: () => closed++,
      forgetOnLastCancel: forget,
    );

    setUp(() {
      opened = 0;
      closed = 0;
    });

    test(
      'open once for many listeners, and close when the last leaves',
      () async {
        source = create();
        final a = source.stream.listen((_) {});
        final b = source.stream.listen((_) {});
        final c = source.stream.listen((_) {});
        expect(opened, 1);

        await a.cancel();
        await b.cancel();
        expect(closed, 0, reason: 'a listener is still there');

        await c.cancel();
        expect(closed, 1);
        expect(opened, 1);
      },
    );

    test('open again for the next listener after everyone left', () async {
      source = create();
      await (source.stream.listen((_) {})).cancel();

      final again = source.stream.listen((_) {});

      expect(opened, 2);
      expect(closed, 1);
      await again.cancel();
    });

    test('a listener that cancels twice closes only once', () async {
      source = create();
      final only = source.stream.listen((_) {});

      await only.cancel();
      await only.cancel();

      expect(closed, 1);
    });

    test(
      'the listener that opens the upstream gets what it emits at once',
      () async {
        late final ReplayLatest<int> shared;
        shared = ReplayLatest<int>.empty(onFirstListener: () => shared.add(7));
        final seen = <int>[];

        final subscription = shared.stream.listen(seen.add);
        await pumpEventQueue();

        expect(seen, [7]);
        await subscription.cancel();
      },
    );

    test('keep the latest value for the next listener by default', () async {
      source = create()..add(1);
      await (source.stream.listen((_) {})).cancel();
      final seen = <int>[];

      final next = source.stream.listen(seen.add);
      await pumpEventQueue();

      expect(seen, [1]);
      await next.cancel();
    });

    test('forget it when asked, so nobody is replayed a stale state', () async {
      source = create(forget: true);
      final first = source.stream.listen((_) {});
      source.add(1);
      await first.cancel();
      expect(source.hasValue, isFalse);
      final seen = <int>[];

      final next = source.stream.listen(seen.add);
      await pumpEventQueue();
      expect(
        seen,
        isEmpty,
        reason: 'the upstream has not spoken since it reopened',
      );

      source.add(2);
      await pumpEventQueue();
      expect(seen, [2]);
      await next.cancel();
    });

    test('do not run when the source is closed', () async {
      source = create();
      var done = false;
      source.stream.listen((_) {}, onDone: () => done = true);

      await source.close();
      await pumpEventQueue();

      expect(done, isTrue);
      expect(closed, 0);
    });

    test('cancelling completes under a fake clock, and the hook has run', () {
      fakeAsync((async) {
        source = create();
        final subscription = source.stream.listen((_) {});
        var cancelled = false;

        unawaited(subscription.cancel().then((_) => cancelled = true));
        async.flushMicrotasks();

        expect(cancelled, isTrue);
        expect(closed, 1);
      });
    });
  });
}
