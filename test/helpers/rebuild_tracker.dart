import 'package:flutter/widgets.dart';

/// The types of the widgets that rebuild while [body] runs, in order, once per
/// rebuild. An empty list means nothing was rebuilt.
///
/// It hooks `debugOnRebuildDirtyWidget`, a single global, so tests that use it
/// must not run concurrently (Flutter runs the tests of one file in sequence).
Future<List<Type>> rebuiltDuring(Future<void> Function() body) async {
  final rebuilt = <Type>[];
  debugOnRebuildDirtyWidget = (element, _) =>
      rebuilt.add(element.widget.runtimeType);
  try {
    await body();
  } finally {
    debugOnRebuildDirtyWidget = null;
  }
  return rebuilt;
}
