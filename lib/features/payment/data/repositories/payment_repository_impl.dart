import 'dart:async';

import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/error/failure_mapper.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_remote_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_progress_dto.dart';
import 'package:secure_payment_portal/features/payment/data/mappers/payment_details_mapper.dart';
import 'package:secure_payment_portal/features/payment/data/mappers/payment_progress_mapper.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_details.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_failures.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_progress.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_repository.dart';

/// Bills come from the remote source; processing runs on the platform source.
final class PaymentRepositoryImpl implements PaymentRepository {
  const PaymentRepositoryImpl({
    required PaymentRemoteDataSource remote,
    required PaymentPlatformDataSource platform,
  }) : _remote = remote,
       _platform = platform;

  final PaymentRemoteDataSource _remote;
  final PaymentPlatformDataSource _platform;

  @override
  Future<Result<PaymentDetails>> getPaymentDetails(String paymentId) async {
    try {
      final dto = await _remote.fetchPaymentDetails(paymentId);
      return Success(PaymentDetailsMapper.toEntity(dto));
    } on DataSourceException catch (error) {
      return Err(failureFromError(error));
    }
  }

  @override
  Future<Result<void>> startPayment(PaymentDetails details) {
    return _command(
      () =>
          _platform.startPayment(PaymentDetailsMapper.toStartRequest(details)),
    );
  }

  @override
  Future<Result<void>> cancelPayment() => _command(_platform.cancelPayment);

  @override
  Stream<PaymentProgress> watchProgress() {
    return _platform
        .watchProgress()
        .transform(
          StreamTransformer<PaymentProgressDto, PaymentProgress>.fromHandlers(
            handleData: (dto, sink) {
              try {
                sink.add(PaymentProgressMapper.toEntity(dto));
              } on DataSourceException catch (error) {
                sink.add(PaymentFailed(failureFromError(error)));
              }
            },
            handleError: (error, stackTrace, sink) =>
                sink.add(PaymentFailed(failureFromError(error))),
          ),
        )
        .distinct();
  }

  Future<Result<void>> _command(Future<void> Function() action) async {
    try {
      await action();
      return Success.unit;
    } on PlatformCallException catch (error) {
      return Err(_failureForPlatformCode(error));
    } on DataSourceException catch (error) {
      return Err(failureFromError(error));
    }
  }

  Failure _failureForPlatformCode(PlatformCallException error) {
    return switch (error.code) {
      ChannelErrorCodes.alreadyRunning => const PaymentInProgressFailure(),
      ChannelErrorCodes.invalidArgs => const InvalidPaymentFailure(),
      _ => failureFromError(error),
    };
  }
}
