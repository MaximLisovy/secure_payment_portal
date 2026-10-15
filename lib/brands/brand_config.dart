import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/core/design_system/tokens/brand_tokens.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';

/// What a brand must declare. Pure configuration: a brand has no logic and no
/// widgets. Feature configs (e.g. the payment screen layout) are added here, one
/// typed field per feature, as those features appear.
class BrandConfig extends Equatable {
  const BrandConfig({
    required this.id,
    required this.displayName,
    required this.tokens,
    required this.payment,
  });

  /// Equals the Android flavor name, e.g. `retail`.
  final String id;
  final String displayName;
  final BrandTokens tokens;

  /// Which bill the payment screen shows and which sections it has.
  final PaymentScreenConfig payment;

  @override
  List<Object?> get props => [id, displayName, tokens, payment];
}
