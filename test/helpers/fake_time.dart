import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Lets a future that does not complete under a widget test's fake clock (the
/// result of cancelling a stream subscription or closing a controller) finish.
///
/// Awaiting such a future directly inside `testWidgets` never returns. Start it
/// and pump instead.
///
/// Related: the done event of a `Stream.multi` (what `ReplayLatest` returns) is
/// not delivered under the fake clock at all. Assert "this stream completes" in
/// a plain `test`, and keep `testWidgets` for what really needs fake time.
Future<void> settle(WidgetTester tester, Future<void> future) async {
  unawaited(future);
  await tester.pump();
}
