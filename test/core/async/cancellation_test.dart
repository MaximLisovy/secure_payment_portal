import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/async/cancellation.dart';

void main() {
  test('cancelling a command is terminal and leaves other commands active', () {
    final owner = CancellationSource();
    final other = CancellationSource();
    final CancellationSignal signal = owner;
    expect(signal.isCancelled, isFalse);
    owner.cancel();
    owner.cancel();
    expect(signal.isCancelled, isTrue);
    expect(other.isCancelled, isFalse);
  });
}
