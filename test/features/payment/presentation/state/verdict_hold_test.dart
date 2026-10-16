import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/features/payment/presentation/state/verdict_hold.dart';

import '../../../../helpers/fake_async_helpers.dart';

const _revolution = Duration(seconds: 2);

void main() {
  test('releases a value at the end of the revolution, not before', () {
    fakeAsync((async) {
      final released = <String>[];
      final hold = VerdictHold<String>(released.add)
        ..start(_revolution)
        ..hold('pass');

      async.elapse(_revolution - const Duration(milliseconds: 1));
      expect(released, isEmpty);

      async.elapse(const Duration(milliseconds: 1));
      expect(released, ['pass']);
      expect(hold.isHolding, isFalse);
      expectNoPendingTimers(async);
    });
  });

  test('releases the latest value offered, once', () {
    fakeAsync((async) {
      final released = <String>[];
      VerdictHold<String>(released.add)
        ..start(_revolution)
        ..hold('first');
      // A second hold replaces the first.
      async.elapse(const Duration(seconds: 1));

      final hold = VerdictHold<String>(released.add)
        ..start(_revolution)
        ..hold('a')
        ..hold('b');
      async.elapse(_revolution);

      expect(released, ['first', 'b']);
      expect(hold.isHolding, isFalse);
    });
  });

  test('a tick with nothing held waits for the next revolution', () {
    fakeAsync((async) {
      final released = <String>[];
      final hold = VerdictHold<String>(released.add)..start(_revolution);

      async.elapse(_revolution * 2 + const Duration(milliseconds: 500));
      expect(released, isEmpty);
      expect(hold.isHolding, isTrue);

      hold.hold('late');
      async.elapse(const Duration(milliseconds: 500));
      expect(released, isEmpty, reason: 'mid-revolution: wait');

      async.elapse(const Duration(milliseconds: 1000));
      expect(released, [
        'late',
      ], reason: 'the end of the revolution it arrived in');
    });
  });

  test('a zero length holds nothing', () {
    fakeAsync((async) {
      final released = <String>[];
      final hold = VerdictHold<String>(released.add)
        ..start(Duration.zero)
        ..hold('x');

      async.elapse(const Duration(seconds: 5));

      expect(hold.isHolding, isFalse);
      expect(released, isEmpty);
      expectNoPendingTimers(async);
    });
  });

  test('stop drops what is held and cancels the timer', () {
    fakeAsync((async) {
      final released = <String>[];
      VerdictHold<String>(released.add)
        ..start(_revolution)
        ..hold('x')
        ..stop();

      async.elapse(const Duration(seconds: 10));

      expect(released, isEmpty);
      expectNoPendingTimers(async);
    });
  });

  test('starting again drops what an earlier start held', () {
    fakeAsync((async) {
      final released = <String>[];
      VerdictHold<String>(released.add)
        ..start(_revolution)
        ..hold('old')
        ..start(_revolution);

      async.elapse(_revolution * 2);

      expect(released, isEmpty);
    });
  });
}
