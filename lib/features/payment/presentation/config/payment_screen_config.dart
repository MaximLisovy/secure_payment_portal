import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/features/payment/presentation/config/payment_section_spec.dart';

/// What a brand decides about the payment screen: which sections appear, in
/// order. The pay action and the security and result states
/// are not configurable: they belong to the page, not to brand content.
class PaymentScreenConfig extends Equatable {
  const PaymentScreenConfig({required this.sections});

  /// Rendered top to bottom between the security slot and the pay bar.
  final List<PaymentSectionSpec> sections;

  @override
  List<Object?> get props => [sections];
}
