import 'package:secure_payment_portal/features/payment/data/dtos/payment_details_dto.dart';

/// The bill backend. There is none, so this stays a fake for good; it sits
/// behind an interface so a real API could replace it.
///
/// Failures are thrown as `DataSourceException`s.
abstract interface class PaymentRemoteDataSource {
  /// Throws `NotFoundException` for an unknown [paymentId] and
  /// `NetworkException` when the backend cannot be reached.
  Future<PaymentDetailsDto> fetchPaymentDetails(String paymentId);
}
