import 'package:flutter/material.dart';
import 'package:secure_payment_portal/app/brand_preview/brand_preview_sections.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';

/// Renders every token family on screen. It reads tokens only, so each brand
/// looks different with no brand-specific code.
class BrandPreviewView extends StatelessWidget {
  const BrandPreviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.brandDensity.spaceMd),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ColorRolesSection(),
          ShapeSection(),
          ControlsSection(),
          DefaultsSection(),
          RowsSection(),
          MotionSection(),
        ],
      ),
    );
  }
}
