import 'package:flutter/material.dart';
import 'package:secure_payment_portal/core/design_system/brand_context.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/core/strings/app_strings.dart';

class DemoSection extends StatelessWidget {
  const DemoSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final density = context.brandDensity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: density.spaceLg),
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        SizedBox(height: density.spaceSm),
        ...children,
      ],
    );
  }
}

class DemoModePicker extends StatelessWidget {
  const DemoModePicker({
    super.key,
    required this.mode,
    required this.realAvailable,
    required this.onSelected,
  });

  final SourceMode mode;
  final bool realAvailable;
  final ValueChanged<SourceMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SourceMode>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: SourceMode.real,
          label: const Text(AppStrings.demoSourceReal),
          enabled: realAvailable,
        ),
        const ButtonSegment(
          value: SourceMode.simulated,
          label: Text(AppStrings.demoSourceSimulated),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => onSelected(selection.single),
    );
  }
}

class DemoChoice<T> extends StatelessWidget {
  const DemoChoice({
    super.key,
    required this.label,
    required this.values,
    required this.selected,
    required this.nameOf,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) nameOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final density = context.brandDensity;
    return Padding(
      padding: EdgeInsets.only(top: density.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          SizedBox(height: density.spaceXs),
          Wrap(
            spacing: density.spaceSm,
            children: [
              for (final value in values)
                ChoiceChip(
                  label: Text(nameOf(value)),
                  selected: value == selected,
                  onSelected: (_) => onSelected(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
