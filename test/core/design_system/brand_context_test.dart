import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_colors.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_density.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_motion.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_shape.dart';

import '../../helpers/token_fixtures.dart';

void main() {
  group('BrandThemeContext', () {
    testWidgets('returns the extensions registered on the theme', (
      tester,
    ) async {
      late BrandColors colors;
      late BrandShape shape;
      late BrandDensity density;
      late BrandMotion motion;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: sampleTokensA.extensions),
          home: Builder(
            builder: (context) {
              colors = context.brandColors;
              shape = context.brandShape;
              density = context.brandDensity;
              motion = context.brandMotion;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(colors, sampleColorsA);
      expect(shape, sampleShapeA);
      expect(density, sampleDensityA);
      expect(motion, sampleMotionA);
    });

    testWidgets('throws a StateError naming the missing extension', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(),
          home: Builder(
            builder: (context) {
              context.brandColors;
              return const SizedBox();
            },
          ),
        ),
      );

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect((error! as StateError).message, contains('BrandColors'));
    });
  });
}
