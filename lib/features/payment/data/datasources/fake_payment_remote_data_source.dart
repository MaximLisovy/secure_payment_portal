import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_bills.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_details_dto.dart';

enum FakeRemoteOutcome { success, networkError }

/// A bill backend with a fixed catalog and a fixed latency: no randomness, so
/// the same call always gives the same result. [outcome] can be changed to play
/// a failing network.
final class FakePaymentRemoteDataSource implements PaymentRemoteDataSource {
  FakePaymentRemoteDataSource({
    this.bills = FakeBills.all,
    this.latency = Duration.zero,
    this.outcome = FakeRemoteOutcome.success,
  });

  final Map<String, PaymentDetailsDto> bills;
  final Duration latency;
  FakeRemoteOutcome outcome;

  @override
  Future<PaymentDetailsDto> fetchPaymentDetails(String paymentId) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (outcome == FakeRemoteOutcome.networkError) {
      throw const NetworkException();
    }
    final bill = bills[paymentId];
    if (bill == null) throw const NotFoundException();
    return bill;
  }
}
