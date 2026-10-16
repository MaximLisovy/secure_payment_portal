import 'dart:async';

import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/error/failure_mapper.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/core/logging/logger.dart';
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
    required Logger logger,
  }) : _remote = remote,
       _platform = platform,
       _logger = logger;

  final PaymentRemoteDataSource _remote;
  final PaymentPlatformDataSource _platform;
  final Logger _logger;

  @override
  Future<Result<PaymentDetails>> getPaymentDetails(String paymentId) async {
    try {
      final dto = await _remote.fetchPaymentDetails(paymentId);
      return Success(PaymentDetailsMapper.toEntity(dto));
    } on DataSourceException catch (error, stackTrace) {
      return Err(_failure(error, stackTrace));
    }
  }

  @override
  Future<Result<void>> preparePayment() => _command(_platform.preparePayment);

  @override
  Future<Result<void>> startPayment(
    PaymentDetails details, {
    required String attemptId,
  }) {
    return _startCommand(details, attemptId);
  }

  Future<Result<void>> _startCommand(
    PaymentDetails details,
    String attemptId,
  ) async {
    try {
      await _platform.startPayment(
        PaymentDetailsMapper.toStartRequest(details, attemptId: attemptId),
      );
      return Success.unit;
    } on PlatformCallException catch (error) {
      // Only these native replies prove this start was rejected. INTERNAL and
      // UNAVAILABLE cannot prove whether the store accepted the attempt.
      return Err(switch (error.code) {
        ChannelErrorCodes.alreadyRunning => const PaymentInProgressFailure(),
        ChannelErrorCodes.invalidArgs => const InvalidPaymentFailure(),
        ChannelErrorCodes.startNotAllowed =>
          const PaymentStartNotAllowedFailure(),
        _ => const PaymentOutcomeUnknownFailure(),
      });
    } on Object catch (error, stackTrace) {
      _failure(error, stackTrace);
      return const Err(PaymentOutcomeUnknownFailure());
    }
  }

  @override
  Future<Result<PaymentProgress>> getPaymentSnapshot({
    required String attemptId,
  }) async {
    try {
      final dto = await _platform.getPaymentSnapshot(attemptId: attemptId);
      return Success(PaymentProgressMapper.toEntity(dto));
    } on Object catch (error, stackTrace) {
      _failure(error, stackTrace);
      return const Err(PaymentOutcomeUnknownFailure());
    }
  }

  @override
  Future<Result<void>> cancelPayment({required String attemptId}) =>
      _command(() => _platform.cancelPayment(attemptId: attemptId));

  @override
  Stream<PaymentProgress> watchProgress() {
    return _platform
        .watchProgress()
        .transform(
          StreamTransformer<PaymentProgressDto, PaymentProgress>.fromHandlers(
            handleData: (dto, sink) {
              try {
                sink.add(PaymentProgressMapper.toEntity(dto));
              } on DataSourceException catch (error, stackTrace) {
                sink.add(PaymentFailed(_failure(error, stackTrace)));
              }
            },
            handleError: (error, stackTrace, sink) =>
                sink.add(PaymentFailed(_failure(error, stackTrace))),
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
    } on DataSourceException catch (error, stackTrace) {
      return Err(_failure(error, stackTrace));
    }
  }

  Failure _failure(Object error, StackTrace stackTrace) =>
      failureFromError(error, logger: _logger, stackTrace: stackTrace);

  Failure _failureForPlatformCode(PlatformCallException error) {
    return switch (error.code) {
      ChannelErrorCodes.alreadyRunning => const PaymentInProgressFailure(),
      ChannelErrorCodes.invalidArgs => const InvalidPaymentFailure(),
      ChannelErrorCodes.startNotAllowed =>
        const PaymentStartNotAllowedFailure(),
      _ => failureFromError(error, logger: _logger),
    };
  }
}
