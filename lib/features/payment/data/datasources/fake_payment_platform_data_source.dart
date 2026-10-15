import 'dart:async';

import 'package:secure_payment_portal/core/async/replay_latest.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/fake_payment_config.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_progress_dto.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/start_payment_request_dto.dart';
import 'package:secure_payment_portal/features/payment/domain/payment_scenario.dart';

/// Simulates the foreground service in Dart: same contract, no platform code.
///
/// `startPayment` emits `running 0` at once, then `config.steps` updates one
/// [FakePaymentConfig.stepDelay] apart (the last one is 100), then the terminal
/// state of the current [scenario] one delay later. Transaction ids count
/// up, and the clock is injectable, so a run is fully reproducible.
final class FakePaymentPlatformDataSource
    implements PaymentPlatformDataSource, PaymentScenarioControl {
  FakePaymentPlatformDataSource({
    this.config = const FakePaymentConfig(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _scenario = config.scenario;

  final FakePaymentConfig config;
  final DateTime Function() _now;
  PaymentScenario _scenario;
  PaymentScenario? _runningScenario;

  final ReplayLatest<PaymentProgressDto> _progress =
      ReplayLatest<PaymentProgressDto>(PaymentProgressDto.idle);
  Timer? _timer;
  StartPaymentRequestDto? _running;
  int _step = 0;
  int _transactionCount = 0;

  /// Applies to the next payment; one already running keeps the script it began with.
  @override
  PaymentScenario get scenario => _scenario;

  @override
  void setScenario(PaymentScenario scenario) => _scenario = scenario;

  @override
  Future<void> startPayment(StartPaymentRequestDto request) async {
    if (request.amountMinor <= 0) {
      throw const PlatformCallException(ChannelErrorCodes.invalidArgs);
    }
    if (_running != null) {
      throw const PlatformCallException(ChannelErrorCodes.alreadyRunning);
    }
    _running = request;
    _runningScenario = _scenario;
    _step = 0;
    _progress.add(PaymentProgressDto.running(request.paymentId, 0));
    _timer = Timer.periodic(config.stepDelay, (_) => _tick());
  }

  @override
  Future<void> cancelPayment() async {
    if (_running == null) return;
    _finish(PaymentProgressDto.cancelled);
  }

  @override
  Stream<PaymentProgressDto> watchProgress() => _progress.stream;

  Future<void> dispose() {
    _timer?.cancel();
    _timer = null;
    return _progress.close();
  }

  void _tick() {
    final request = _running;
    final scenario = _runningScenario;
    if (request == null || scenario == null) return;
    _step++;
    if (_step <= config.steps) {
      _progress.add(
        PaymentProgressDto.running(
          request.paymentId,
          _step * 100 ~/ config.steps,
        ),
      );
      return;
    }
    _finish(_terminalFor(request, scenario));
  }

  PaymentProgressDto _terminalFor(
    StartPaymentRequestDto request,
    PaymentScenario scenario,
  ) {
    switch (scenario) {
      case PaymentScenario.success:
        _transactionCount++;
        return PaymentProgressDto.succeeded(
          paymentId: request.paymentId,
          transactionId:
              'FAKE-TX-${_transactionCount.toString().padLeft(6, '0')}',
          amountMinor: request.amountMinor,
          currency: request.currency,
          completedAtMillis: _now().millisecondsSinceEpoch,
        );
      case PaymentScenario.declined:
        return const PaymentProgressDto.failed(PaymentChannel.failureDeclined);
      case PaymentScenario.processingFailure:
        return const PaymentProgressDto.failed(
          PaymentChannel.failureProcessing,
        );
    }
  }

  void _finish(PaymentProgressDto terminal) {
    _timer?.cancel();
    _timer = null;
    _running = null;
    _runningScenario = null;
    _progress.add(terminal);
  }
}
