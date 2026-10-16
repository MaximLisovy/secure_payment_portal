import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Reads the source of `lib/` to hold the rules of AGENTS.md section 3 that the
// analyzer cannot. They are checked on imports and identifiers, so they are
// cheap and exact; they do not parse Dart.

const _package = 'package:secure_payment_portal/';

/// Every Dart file under [directory], with its path relative to `lib/`.
Map<String, String> _sources(String directory) => {
  for (final entity in Directory('lib/$directory').listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.dart'))
      entity.path.substring('lib/'.length): entity.readAsStringSync(),
};

/// The package paths a file imports or exports, without the package prefix.
List<String> _imports(String source) => [
  for (final match in RegExp(
    '''^(?:import|export) '$_package([^']+)''',
    multiLine: true,
  ).allMatches(source))
    match.group(1)!,
];

/// Files of [sources] that import something matching [forbidden].
List<String> _violations(
  Map<String, String> sources,
  bool Function(String file, String imported) forbidden,
) => [
  for (final MapEntry(key: file, value: source) in sources.entries)
    for (final imported in _imports(source))
      if (forbidden(file, imported)) '$file imports $imported',
];

bool _isFeatureData(String path) =>
    RegExp(r'^features/[^/]+/data/').hasMatch(path);

void main() {
  final all = _sources('');

  test('the sources were found', () {
    expect(all.length, greaterThan(50));
  });

  group('logging', () {
    test('nothing prints: the one way to say something is the Logger', () {
      final bad = [
        for (final MapEntry(key: file, value: source) in all.entries)
          if (RegExp(r'(?<![\w.])(print|debugPrint)\(').hasMatch(source)) file,
      ];

      expect(bad, isEmpty, reason: 'print or debugPrint in: ${bad.join(', ')}');
    });

    test('only the logger talks to dart:developer', () {
      final bad = [
        for (final MapEntry(key: file, value: source) in all.entries)
          if (!file.startsWith('core/logging/') &&
              source.contains("import 'dart:developer"))
            file,
      ];

      expect(bad, isEmpty, reason: bad.join(', '));
    });
  });

  group('the dependency rule', () {
    test('domain code is pure Dart', () {
      final domain = {
        for (final e in all.entries)
          if (RegExp(r'/domain/|^core/domain/|_domain\.dart$').hasMatch(e.key))
            e.key: e.value,
      };
      expect(domain, isNotEmpty);

      final bad = [
        for (final MapEntry(key: file, value: source) in domain.entries)
          for (final match in RegExp(
            r'''^(?:import|export) '(?:package:(flutter|flutter_riverpod|riverpod)/|dart:ui)''',
            multiLine: true,
          ).allMatches(source))
            '$file imports ${match.group(0)}',
      ];

      expect(bad, isEmpty, reason: bad.join('\n'));
    });

    test('presentation, the app and brands never import a data layer', () {
      final consumers = {
        for (final e in all.entries)
          if (e.key.contains('/presentation/') ||
              e.key.startsWith('app/') ||
              e.key.startsWith('brands/'))
            e.key: e.value,
      };

      final bad = _violations(
        consumers,
        (_, imported) => _isFeatureData(imported),
      );

      expect(bad, isEmpty, reason: bad.join('\n'));
    });

    test('a feature never imports another feature\'s internals', () {
      final bad = _violations(_sources('features'), (file, imported) {
        final from = file.split('/')[1];
        if (!imported.startsWith('features/')) return false;
        final parts = imported.split('/');
        final to = parts[1];
        // Another feature is reached through its public barrel only.
        return to != from && parts.length > 3;
      });

      expect(bad, isEmpty, reason: bad.join('\n'));
    });

    test('core knows nothing of the app, brands or features', () {
      final bad = _violations(
        _sources('core'),
        (_, imported) =>
            imported.startsWith('app/') ||
            imported.startsWith('brands/') ||
            imported.startsWith('features/'),
      );

      expect(bad, isEmpty, reason: bad.join('\n'));
    });
  });

  group('multi-tenancy', () {
    test('only the brand registry reads the flavor', () {
      final bad = [
        for (final MapEntry(key: file, value: source) in all.entries)
          if (file != 'app/brand/brand_registry.dart' &&
              source.contains('appFlavor'))
            file,
      ];

      expect(bad, isEmpty, reason: 'reads the flavor: ${bad.join(', ')}');
    });

    test('features and core name no brand', () {
      final bad = [
        for (final MapEntry(key: file, value: source) in all.entries)
          if ((file.startsWith('features/') || file.startsWith('core/')) &&
              RegExp(r'''['"](retail|utility)['"]''').hasMatch(source))
            file,
      ];

      expect(bad, isEmpty, reason: 'names a brand: ${bad.join(', ')}');
    });
  });

  group('simulation', () {
    test('the app steers simulations through control interfaces only', () {
      final bad = [
        for (final MapEntry(key: file, value: source) in _sources(
          'app',
        ).entries)
          if (RegExp(r'\bFake[A-Z]\w*').hasMatch(source)) file,
      ];

      expect(bad, isEmpty, reason: 'mentions a fake: ${bad.join(', ')}');
    });

    test('nothing downcasts to a fake', () {
      final bad = [
        for (final MapEntry(key: file, value: source) in all.entries)
          if (RegExp(r'\b(?:is|as)!?\s+Fake[A-Z]').hasMatch(source)) file,
      ];

      expect(bad, isEmpty, reason: 'downcasts to a fake: ${bad.join(', ')}');
    });
  });
}
