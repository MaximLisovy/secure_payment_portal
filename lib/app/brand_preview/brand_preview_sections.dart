import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';

/// A titled block of the brand preview.
class PreviewSection extends StatelessWidget {
  const PreviewSection({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final density = context.brandDensity;
    return Padding(
      padding: EdgeInsets.only(bottom: density.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: context.brandColors.onSurfaceMuted,
            ),
          ),
          SizedBox(height: density.spaceSm),
          child,
        ],
      ),
    );
  }
}

class ColorRolesSection extends StatelessWidget {
  const ColorRolesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.brandColors;
    final density = context.brandDensity;
    final shape = context.brandShape;
    return PreviewSection(
      title: AppStrings.previewColors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: density.spaceSm,
            runSpacing: density.spaceSm,
            children: [
              _Swatch(AppStrings.roleBrandPrimary, colors.brandPrimary),
              _Swatch(AppStrings.roleBrandAccent, colors.brandAccent),
              _Swatch(AppStrings.roleBrandOnSurface, colors.brandOnSurface),
              _Swatch(AppStrings.roleSurfaceElevated, colors.surfaceElevated),
              _Swatch(AppStrings.roleSuccess, colors.success),
              _Swatch(AppStrings.roleDanger, colors.danger),
              _Swatch(AppStrings.roleScanGlow, colors.scanGlow),
            ],
          ),
          SizedBox(height: density.spaceSm),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: colors.brandGradient,
              borderRadius: shape.borderRadiusMd,
            ),
            child: SizedBox(
              height: density.controlHeight,
              width: double.infinity,
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.brandColors;
    final density = context.brandDensity;
    final shape = context.brandShape;
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: shape.borderRadiusSm,
            border: Border.fromBorderSide(
              shape.borderSide(colors.outlineSubtle),
            ),
          ),
          child: SizedBox(
            width: density.rowHeight,
            height: density.controlHeight,
          ),
        ),
        SizedBox(height: density.spaceXs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.onSurface),
        ),
      ],
    );
  }
}

class ShapeSection extends StatelessWidget {
  const ShapeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final shape = context.brandShape;
    final density = context.brandDensity;
    return PreviewSection(
      title: AppStrings.previewShape,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RadiusSample(AppStrings.radiusSm, shape.borderRadiusSm),
              SizedBox(width: density.spaceSm),
              _RadiusSample(AppStrings.radiusMd, shape.borderRadiusMd),
              SizedBox(width: density.spaceSm),
              _RadiusSample(AppStrings.radiusLg, shape.borderRadiusLg),
            ],
          ),
          SizedBox(height: density.spaceSm),
          SizedBox(
            width: double.infinity,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(density.spaceMd),
                child: const Text(AppStrings.cardLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadiusSample extends StatelessWidget {
  const _RadiusSample(this.label, this.radius);

  final String label;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.brandColors;
    final density = context.brandDensity;
    final shape = context.brandShape;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: radius,
        border: Border.fromBorderSide(shape.borderSide(colors.outlineSubtle)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: density.spaceMd,
          vertical: density.spaceSm,
        ),
        child: Text(label),
      ),
    );
  }
}

class ControlsSection extends StatelessWidget {
  const ControlsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final density = context.brandDensity;
    return PreviewSection(
      title: AppStrings.previewControls,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: density.spaceSm,
            runSpacing: density.spaceSm,
            children: [
              FilledButton(
                onPressed: () {},
                child: const Text(AppStrings.buttonFilled),
              ),
              OutlinedButton(
                onPressed: () {},
                child: const Text(AppStrings.buttonOutlined),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(AppStrings.buttonText),
              ),
            ],
          ),
          SizedBox(height: density.spaceMd),
          const TextField(
            decoration: InputDecoration(labelText: AppStrings.fieldLabel),
          ),
        ],
      ),
    );
  }
}

/// Plain Material widgets with no brand styling: they must still read well,
/// because `ColorScheme.primary` is the accessible brand foreground.
class DefaultsSection extends StatefulWidget {
  const DefaultsSection({super.key});

  @override
  State<DefaultsSection> createState() => _DefaultsSectionState();
}

class _DefaultsSectionState extends State<DefaultsSection> {
  bool _checked = true;
  double _level = 0.6;

  @override
  Widget build(BuildContext context) {
    return PreviewSection(
      title: AppStrings.previewDefaults,
      child: Row(
        children: [
          Switch(
            value: _checked,
            onChanged: (value) => setState(() => _checked = value),
          ),
          Checkbox(
            value: _checked,
            onChanged: (value) => setState(() => _checked = value ?? false),
          ),
          Expanded(
            child: Slider(
              value: _level,
              onChanged: (value) => setState(() => _level = value),
            ),
          ),
        ],
      ),
    );
  }
}

class RowsSection extends StatelessWidget {
  const RowsSection({super.key});

  static const _rowCount = 3;

  @override
  Widget build(BuildContext context) {
    return PreviewSection(
      title: AppStrings.previewRows,
      child: SizedBox(
        width: double.infinity,
        child: Card(
          child: Column(
            children: [
              for (var i = 1; i <= _rowCount; i++) ...[
                if (i > 1) const Divider(),
                ListTile(
                  title: Text(AppStrings.rowTitle(i)),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the brand's motion tokens: the bar grows with `slow` + `emphasized`.
class MotionSection extends StatefulWidget {
  const MotionSection({super.key});

  @override
  State<MotionSection> createState() => _MotionSectionState();
}

class _MotionSectionState extends State<MotionSection> {
  static const _collapsedFactor = 0.3;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final density = context.brandDensity;
    final motion = context.brandMotion;
    return PreviewSection(
      title: AppStrings.previewMotion,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: const Text(AppStrings.motionToggle),
          ),
          SizedBox(height: density.spaceSm),
          SizedBox(
            height: density.controlHeight,
            child: AnimatedFractionallySizedBox(
              duration: motion.slow,
              curve: motion.emphasized,
              alignment: Alignment.centerLeft,
              widthFactor: _expanded ? 1 : _collapsedFactor,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: context.brandColors.brandGradient,
                  borderRadius: context.brandShape.borderRadiusMd,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
