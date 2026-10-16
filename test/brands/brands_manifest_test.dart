import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';

/// `android/brands.json` is what Gradle turns into product flavors, and the CI
/// build matrix is read from it. The registry is what the app resolves a flavor
/// against. They must list the same brands, or a flavor would start and throw.
List<Map<String, Object?>> _manifest() {
  final decoded = jsonDecode(File('android/brands.json').readAsStringSync());
  return [
    for (final entry in decoded as List<Object?>)
      Map<String, Object?>.from(entry! as Map),
  ];
}

void main() {
  final manifest = _manifest();
  const registry = BrandRegistry.standard;

  test('lists at least one brand, each with the three fields and no more', () {
    expect(manifest, isNotEmpty);
    for (final brand in manifest) {
      expect(
        brand.keys,
        unorderedEquals(['id', 'displayName', 'applicationIdSuffix']),
      );
      for (final value in brand.values) {
        expect(value, isA<String>());
        expect((value! as String).trim(), isNotEmpty);
      }
    }
  });

  test('has unique ids that are safe as a flavor name', () {
    final ids = [for (final brand in manifest) brand['id']! as String];
    expect(ids.toSet(), hasLength(ids.length), reason: 'a duplicate id');
    for (final id in ids) {
      expect(id, matches(RegExp(r'^[a-z][a-z0-9]*$')));
    }
  });

  test('gives every brand the suffix that is its id', () {
    for (final brand in manifest) {
      expect(brand['applicationIdSuffix'], '.${brand['id']}');
    }
  });

  test('lists exactly the brands the registry knows', () {
    expect(
      {for (final brand in manifest) brand['id']! as String},
      {for (final brand in registry.all) brand.id},
    );
  });

  test('gives each brand the display name its config has', () {
    for (final brand in manifest) {
      final config = registry.byId(brand['id']! as String);
      expect(config, isNotNull, reason: '${brand['id']} is not registered');
      expect(
        brand['displayName'],
        config!.displayName,
        reason: '${brand['id']}',
      );
    }
  });

  test('includes the brand the registry falls back to outside release', () {
    expect([
      for (final brand in manifest) brand['id'],
    ], contains(registry.defaultBrandId));
  });
}
