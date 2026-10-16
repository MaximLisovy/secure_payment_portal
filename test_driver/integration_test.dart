import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

import 'scan_performance_summary.dart';

/// Runs the integration tests on the device and writes what they report to
/// `build/scan_performance/`: the raw report, and the summary as JSON and as a
/// table.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final directory = Directory('build/scan_performance')
      ..createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    File('${directory.path}/raw.json').writeAsStringSync(encoder.convert(data));

    final summary = ScanPerformanceSummary.fromReport(data);
    File(
      '${directory.path}/summary.json',
    ).writeAsStringSync(encoder.convert(summary.toJson()));
    final table = summary.toMarkdown();
    File('${directory.path}/summary.md').writeAsStringSync(table);
    stdout.write('\n$table');
  },
);
