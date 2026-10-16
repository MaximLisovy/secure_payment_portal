import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/features/payment/presentation/config/payment_section_spec.dart';
import 'package:secure_payment_portal/features/payment/presentation/sections/bill_breakdown_section.dart';
import 'package:secure_payment_portal/features/payment/presentation/sections/promo_banner_section.dart';
import 'package:secure_payment_portal/features/payment/presentation/sections/summary_section.dart';

typedef SectionBuilder<S extends PaymentSectionSpec> =
    Widget Function(BuildContext context, S spec);

/// Turns a brand's section specs into widgets. Each builder returns a *sliver*,
/// so the page can lay all sections out in one lazy scroll view; wrap box
/// content in a `SliverToBoxAdapter`.
///
/// Immutable: [adding] returns a new registry. Keyed by the spec's exact type, so
/// a new section type is one more entry, with no `switch` to edit.
final class PaymentSectionRegistry {
  const PaymentSectionRegistry.empty() : _builders = const {};

  const PaymentSectionRegistry._(this._builders);

  /// The built-in sections. To add a section type, add one `.adding` here.
  factory PaymentSectionRegistry.standard() =>
      const PaymentSectionRegistry.empty()
          .adding<SummarySpec>((context, spec) => const SummarySection())
          .adding<PromoBannerSpec>(
            (context, spec) => PromoBannerSection(spec: spec),
          )
          .adding<BillBreakdownSpec>(
            (context, spec) => const BillBreakdownSection(),
          );

  final Map<Type, Widget Function(BuildContext, PaymentSectionSpec)> _builders;

  PaymentSectionRegistry adding<S extends PaymentSectionSpec>(
    SectionBuilder<S> builder,
  ) {
    return PaymentSectionRegistry._({
      ..._builders,
      S: (context, spec) => builder(context, spec as S),
    });
  }

  @visibleForTesting
  bool supports(PaymentSectionSpec spec) =>
      _builders.containsKey(spec.runtimeType);

  /// Throws a [StateError] naming the spec if nothing is registered for it: a
  /// brand that declares a section nobody can draw is a bug, not a blank gap.
  Widget build(BuildContext context, PaymentSectionSpec spec) {
    final builder = _builders[spec.runtimeType];
    if (builder == null) {
      throw StateError(
        'No widget is registered for ${spec.runtimeType}. '
        'Add it to PaymentSectionRegistry.standard().',
      );
    }
    return builder(context, spec);
  }
}

final paymentSectionRegistryProvider = Provider<PaymentSectionRegistry>(
  (ref) => PaymentSectionRegistry.standard(),
);
