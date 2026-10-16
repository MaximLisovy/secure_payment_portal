import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// The driver for `integration_test/payment_flow_test.dart`: grants the
/// notification permission on the emulator before the test starts, and writes the
/// test's report to `build/payment_integration/<flavor>.json`.
///
/// It reads `PAYMENT_TEST_DEVICE` (the emulator's serial) and `PAYMENT_TEST_FLAVOR`
/// (a brand id from `android/brands.json`) from the environment, and refuses
/// anything but an emulator. See the test's header for the full command.
Future<void> main() async {
  await _prepareEmulator();
  await integrationDriver(
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      final directory = Directory('build/payment_integration')
        ..createSync(recursive: true);
      final label = Platform.environment['PAYMENT_TEST_FLAVOR'] ?? 'latest';
      File(
        '${directory.path}/$label.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
    },
  );
}

/// Prepare permission after installation, before resuming the test isolate.
Future<void> _prepareEmulator() async {
  final serial = Platform.environment['PAYMENT_TEST_DEVICE'];
  final flavor = Platform.environment['PAYMENT_TEST_FLAVOR'];
  if (serial == null || flavor == null) {
    throw StateError('Set PAYMENT_TEST_DEVICE and PAYMENT_TEST_FLAVOR.');
  }
  final sdkLine = File(
    'android/local.properties',
  ).readAsLinesSync().firstWhere((line) => line.startsWith('sdk.dir='));
  final adb = '${sdkLine.substring('sdk.dir='.length)}/platform-tools/adb';
  Future<String> shell(List<String> arguments) async {
    final result = await Process.run(adb, [
      '-s',
      serial,
      'shell',
      ...arguments,
    ]);
    if (result.exitCode != 0) {
      throw StateError('ADB setup failed: ${result.stderr}');
    }
    return result.stdout.toString().trim();
  }

  if (await shell(['getprop', 'ro.kernel.qemu']) != '1') {
    throw StateError('Automatic notification setup supports emulators only.');
  }
  final entries =
      jsonDecode(File('android/brands.json').readAsStringSync())
          as List<Object?>;
  final entry = entries.cast<Map<String, Object?>>().firstWhere(
    (entry) => entry['id'] == flavor,
  );
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final base = RegExp(
    r'applicationId = "([^"]+)"',
  ).firstMatch(gradle)?.group(1);
  if (base == null) throw StateError('Application ID is not configured.');
  // POST_NOTIFICATIONS is a runtime permission only on API 33+.
  if (int.parse(await shell(['getprop', 'ro.build.version.sdk'])) >= 33) {
    await shell([
      'pm',
      'grant',
      '$base${entry['applicationIdSuffix']}',
      'android.permission.POST_NOTIFICATIONS',
    ]);
  }
}
