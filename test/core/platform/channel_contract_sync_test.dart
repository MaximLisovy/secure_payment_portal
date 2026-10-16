import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Channels.kt mirrors channel_contract.dart. Nothing else keeps two files in two
// languages equal, so this test reads both and compares every constant: same
// object, same name (camelCase here, UPPER_SNAKE there), same value.

const _dartFile = 'lib/core/platform/channel_contract.dart';
const _kotlinFile =
    'android/app/src/main/kotlin/com/hypertenant/secure_payment_portal/bridge/Channels.kt';

String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');

/// The body of every top-level `<keyword> Name {` ... `}` block (closing brace
/// at column 0), by class name.
Map<String, String> _blocks(String source, String keyword) {
  final blocks = <String, String>{};
  final open = RegExp('^$keyword (\\w+) \\{\$', multiLine: true);
  for (final match in open.allMatches(source)) {
    final end = source.indexOf(RegExp(r'^\}', multiLine: true), match.end);
    blocks[match.group(1)!] = source.substring(match.end, end);
  }
  return blocks;
}

String _snake(String camel) => camel
    .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m.group(0)}')
    .toUpperCase();

/// `namespace` and `NAMESPACE` are the same constant: key both as UPPER_SNAKE.
String _key(String name) => name == name.toUpperCase() ? name : _snake(name);

Map<String, String> parseDart(String source) {
  final clean = _withoutComments(source);
  final constants = <String, String>{};
  final blocks = _blocks(clean, r'abstract final class');
  for (final MapEntry(key: owner, value: body) in blocks.entries) {
    for (final match in RegExp(
      r'static const (?:String|int) (\w+) =\s*([^;]+);',
    ).allMatches(body)) {
      constants['$owner.${_key(match.group(1)!)}'] = match.group(2)!.trim();
    }
  }
  return constants;
}

Map<String, String> parseKotlin(String source) {
  final clean = _withoutComments(source);
  final constants = <String, String>{};
  for (final MapEntry(key: owner, value: body) in _blocks(
    clean,
    'object',
  ).entries) {
    for (final match in RegExp(
      r'const val (\w+)(?:: \w+)? = ([^\n]+)',
    ).allMatches(body)) {
      constants['$owner.${match.group(1)}'] = match.group(2)!.trim();
    }
  }
  return constants;
}

/// A literal, with `${Owner.NAME}` templates replaced, so that the same value
/// written two ways compares equal.
String _resolve(String raw, Map<String, String> all) {
  var value = raw;
  for (var pass = 0; pass < 4 && value.contains(r'${'); pass++) {
    value = value.replaceAllMapped(
      RegExp(r'\$\{(\w+)\.(\w+)\}'),
      (m) => _unquote(
        all['${m.group(1)}.${_key(m.group(2)!)}'] ?? '?${m.group(0)}',
      ),
    );
  }
  return _unquote(value);
}

String _unquote(String literal) {
  final quoted = RegExp('^[\'"](.*)[\'"]\$', dotAll: true).firstMatch(literal);
  return quoted == null ? literal : quoted.group(1)!;
}

/// Every way the two sources disagree. Empty when they agree.
List<String> differences(String dartSource, String kotlinSource) {
  final dart = parseDart(dartSource);
  final kotlin = parseKotlin(kotlinSource);
  final problems = <String>[];
  for (final MapEntry(key: name, value: raw) in dart.entries) {
    final other = kotlin[name];
    if (other == null) {
      problems.add('$name is in Dart but not in Kotlin');
    } else if (_resolve(raw, dart) != _resolve(other, kotlin)) {
      problems.add(
        '$name differs: Dart "${_resolve(raw, dart)}", '
        'Kotlin "${_resolve(other, kotlin)}"',
      );
    }
  }
  for (final name in kotlin.keys) {
    if (!dart.containsKey(name)) {
      problems.add('$name is in Kotlin but not in Dart');
    }
  }
  return problems;
}

void main() {
  final dartSource = File(_dartFile).readAsStringSync();
  final kotlinSource = File(_kotlinFile).readAsStringSync();

  test('Channels.kt mirrors channel_contract.dart exactly', () {
    final problems = differences(dartSource, kotlinSource);

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  group('the comparison itself', () {
    test('finds the constants it is supposed to compare', () {
      final dart = parseDart(dartSource);

      expect(dart.length, greaterThan(40));
      expect(dart['SecurityChannel.METHODS'], isNotNull);
      expect(dart['PaymentChannel.FAILURE_PROCESSING'], isNotNull);
      expect(dart['PaymentChannel.GET_PAYMENT_SNAPSHOT'], isNotNull);
      expect(
        parseKotlin(kotlinSource).keys.toSet(),
        dart.keys.toSet(),
        reason: 'name mapping camelCase -> UPPER_SNAKE must be total',
      );
    });

    test('resolves templates, so a value written two ways is equal', () {
      expect(
        _resolve(
          parseDart(dartSource)['SecurityChannel.RECORDING_EVENTS']!,
          parseDart(dartSource),
        ),
        'com.hypertenant.secure_payment_portal/security/screen_recording',
      );
    });

    test('catches a changed value', () {
      final drifted = kotlinSource.replaceFirst(
        '"UNAVAILABLE"',
        '"UNAVAILABLE_"',
      );

      expect(differences(dartSource, drifted), hasLength(1));
    });

    test('catches a constant missing on either side', () {
      final withoutKotlin = kotlinSource.replaceFirst(
        RegExp(r'\s*const val START_NOT_ALLOWED = [^\n]+'),
        '',
      );
      final extraKotlin = kotlinSource.replaceFirst(
        'object DetectionWire {',
        'object DetectionWire {\n    const val EXTRA = "x"',
      );

      expect(differences(dartSource, withoutKotlin), hasLength(1));
      expect(differences(dartSource, extraKotlin), hasLength(1));
    });

    test('catches a changed channel namespace through the templates', () {
      final drifted = kotlinSource.replaceFirst(
        'const val NAMESPACE = "com.hypertenant.secure_payment_portal"',
        'const val NAMESPACE = "com.other"',
      );

      // The namespace and every channel name built from it.
      expect(differences(dartSource, drifted), hasLength(5));
    });
  });
}
