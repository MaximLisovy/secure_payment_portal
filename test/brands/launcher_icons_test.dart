import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/app/brand/brand_registry.dart';

/// The launcher icons are drawn from the brand tokens, not beside them: a brand
/// whose colours change gets a test failure until its icon follows. The icon
/// files live in `android/app/src/<id>/res`, and Gradle refuses a brand that has
/// none.
const _densities = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

List<String> _brandIds() {
  final manifest =
      jsonDecode(File('android/brands.json').readAsStringSync())
          as List<Object?>;
  return [for (final entry in manifest) (entry! as Map)['id']! as String];
}

Directory _res(String id) => Directory('android/app/src/$id/res');

/// `#RRGGBB` of each `<color name="...">` in the brand's icon colours.
Map<String, int> _colours(String id) {
  final xml = File(
    '${_res(id).path}/values/ic_launcher_colors.xml',
  ).readAsStringSync();
  return {
    for (final match in RegExp(
      r'<color name="(\w+)"[^>]*>#([0-9A-Fa-f]{6})</color>',
    ).allMatches(xml))
      match.group(1)!: 0xFF000000 | int.parse(match.group(2)!, radix: 16),
  };
}

int _rgb(Color color) => color.toARGB32() | 0xFF000000;

Future<ui.Image> _decode(File file) async {
  final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

/// The colour of pixel ([x], [y]) as 0xAARRGGBB.
Future<int> _pixel(ui.Image image, int x, int y) async {
  final data = (await image.toByteData())!;
  final offset = (y * image.width + x) * 4;
  return (data.getUint8(offset + 3) << 24) |
      (data.getUint8(offset) << 16) |
      (data.getUint8(offset + 1) << 8) |
      data.getUint8(offset + 2);
}

void main() {
  for (final id in _brandIds()) {
    group('launcher icon of $id', () {
      final brand = BrandRegistry.standard.byId(id);
      final colours = _colours(id);

      test('is a brand the registry knows', () {
        expect(brand, isNotNull);
      });

      test('takes its colours from the brand tokens', () {
        final tokens = brand!.tokens.colors;
        expect(colours['ic_launcher_background'], _rgb(tokens.brandPrimary));
        expect(colours['ic_launcher_glyph'], _rgb(tokens.onBrandPrimary));
        expect(colours['ic_launcher_accent'], _rgb(tokens.brandAccent));
      });

      test(
        'has an adaptive icon with a background, glyph and themed layer',
        () {
          for (final name in ['ic_launcher', 'ic_launcher_round']) {
            final xml = File(
              '${_res(id).path}/mipmap-anydpi-v26/$name.xml',
            ).readAsStringSync();
            expect(xml, contains('<adaptive-icon'), reason: name);
            expect(
              xml,
              contains('@color/ic_launcher_background'),
              reason: name,
            );
            expect(xml, contains('<foreground'), reason: name);
            expect(xml, contains('<monochrome'), reason: name);
          }
        },
      );

      test('draws its glyph from colours it defines, inside the safe zone', () {
        final xml = File(
          '${_res(id).path}/drawable/ic_launcher_foreground.xml',
        ).readAsStringSync();
        expect(xml, contains('android:viewportWidth="108"'));
        expect(xml, contains('android:pathData='));
        for (final match in RegExp(r'@color/(\w+)').allMatches(xml)) {
          expect(colours, contains(match.group(1)), reason: match.group(0));
        }
        // Every coordinate of an absolute move or line stays within the 66 dp
        // that the launcher never crops (21 to 87 of 108).
        for (final data in RegExp(r'pathData="([^"]+)"').allMatches(xml)) {
          final numbers = RegExp(
            r'-?\d+(\.\d+)?',
          ).allMatches(data.group(1)!).map((m) => double.parse(m.group(0)!));
          expect(numbers.every((n) => n >= 0 && n <= 108), isTrue);
        }
      });

      for (final MapEntry(key: density, value: size) in _densities.entries) {
        for (final name in ['ic_launcher', 'ic_launcher_round']) {
          testWidgets('$name at $density is a $size px PNG in the brand colour', (
            tester,
          ) async {
            final file = File('${_res(id).path}/mipmap-$density/$name.png');
            expect(file.existsSync(), isTrue);
            await tester.runAsync(() async {
              final image = await _decode(file);
              expect([image.width, image.height], [size, size]);
              // Near the top edge of the tile, clear of the glyph: the brand colour.
              final background = colours['ic_launcher_background']!;
              expect(
                await _pixel(image, size ~/ 2, (size * 0.08).round() + 1),
                background,
              );
              // Both have clear corners: rounded for the square icon, round for the other.
              final corner = await _pixel(image, 0, 0);
              expect(
                corner >> 24,
                0,
                reason: 'the corner pixel of $name is transparent',
              );
            });
          });
        }
      }

      test(
        'leaves no stale default icon in main, which would hide a missing one',
        () {
          expect(
            Directory('android/app/src/main/res')
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.contains('ic_launcher')),
            isEmpty,
          );
        },
      );
    });
  }
}
