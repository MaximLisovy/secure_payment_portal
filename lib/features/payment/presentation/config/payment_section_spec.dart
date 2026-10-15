import 'package:equatable/equatable.dart';

/// One block of the payment screen, as a brand declares it. Pure data: the
/// widget that renders it is looked up in the `PaymentSectionRegistry`.
///
/// The hierarchy is deliberately open (not `sealed`): a new section type is a new
/// subclass, a widget and one registry entry, with no `switch` to edit. A brand
/// that only reuses existing sections touches none of this.
abstract class PaymentSectionSpec extends Equatable {
  const PaymentSectionSpec();
}

/// Who is paid, what for, and the total.
final class SummarySpec extends PaymentSectionSpec {
  const SummarySpec();

  @override
  List<Object?> get props => [];
}

/// A promotional banner. The copy is brand copy, so it lives in the brand config.
final class PromoBannerSpec extends PaymentSectionSpec {
  const PromoBannerSpec({required this.headline, required this.body});

  final String headline;
  final String body;

  @override
  List<Object?> get props => [headline, body];
}

/// The bill's line items as a dense, lazily built list.
final class BillBreakdownSpec extends PaymentSectionSpec {
  const BillBreakdownSpec();

  @override
  List<Object?> get props => [];
}
