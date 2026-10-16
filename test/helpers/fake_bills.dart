import 'package:secure_payment_portal/app/brand/brand_registry.dart';
import 'package:secure_payment_portal/brands/retail/retail_demo_bill.dart';
import 'package:secure_payment_portal/brands/utility/utility_demo_bill.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_details_dto.dart';
import 'package:secure_payment_portal/features/payment/data/mappers/payment_details_mapper.dart';

/// Test-only adapters for registration-owned demo bills; production features
/// have an empty default catalog and receive registered bills through root DI.
abstract final class FakeBills {
  static const retailOrderId = retailDemoPaymentId;
  static const utilityBillId = utilityDemoPaymentId;
  static final retailOrder = PaymentDetailsMapper.toDto(
    retailDemoBill.toDetails(),
  );
  static final utilityBill = PaymentDetailsMapper.toDto(
    utilityDemoBill.toDetails(),
  );
  static final Map<String, PaymentDetailsDto> all = {
    for (final bill in BrandRegistry.standard.demoBills)
      bill.id: PaymentDetailsMapper.toDto(bill.toDetails()),
  };
}
