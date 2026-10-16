import 'dart:async';

import 'package:flutter/services.dart';
import 'package:secure_payment_portal/core/async/replay_latest.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/logging/logger.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/datasources/payment_platform_data_source.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_progress_dto.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/start_payment_request_dto.dart';

/// The Kotlin foreground service, reached over its two channels. It honours the
/// same contract as the fake (the contract suite runs against both), so either
/// sits behind the repository unchanged.
///
/// Failures are the typed `DataSourceException`s, never platform types: an error
/// reply keeps its code (`ALREADY_RUNNING`, `START_NOT_ALLOWED`, `INVALID_ARGS`),
/// no native side is [UnsupportedException], and a call that is never answered is
/// `PlatformCallException(UNAVAILABLE)` after [callTimeout], so a hang is an
/// explicit failure.
///
/// **Notification permission.** [startPayment] first asks for it through the
/// bridge, and does not wait on it with a timeout: the system prompt can take as
/// long as the user does. Whatever the answer, and even if asking fails, the
/// payment starts: a denial only means the notification is not shown. Only
/// `startPayment` itself is timed, and it is quick (the work runs in the service).
///
/// **One native listener.** The progress `EventChannel` keeps a single active
/// sink, so however many Dart listeners there are, one native subscription is
/// open: opened for the first, closed after the last, each listener replayed the
/// latest state (a terminal one stays current until the next payment) and never
/// one from before the subscription reopened. An event that cannot be read, or an
/// error event, reaches the listeners as a typed error, which the repository turns
/// into a failed payment.
final class ChannelPaymentPlatformDataSource
    implements PaymentPlatformDataSource {
  ChannelPaymentPlatformDataSource({
    required MethodChannel methods,
    required EventChannel progressEvents,
    required Logger logger,
    this.callTimeout = const Duration(seconds: 5),
  }) : _methods = methods,
       _progressEvents = progressEvents,
       _logger = logger {
    _progress = ReplayLatest<PaymentProgressDto>.empty(
      onFirstListener: _openNative,
      onLastCancel: _closeNative,
      forgetOnLastCancel: true,
    );
  }

  final MethodChannel _methods;
  final EventChannel _progressEvents;
  final Logger _logger;

  /// How long a method call may take before it counts as unavailable.
  final Duration callTimeout;

  late final ReplayLatest<PaymentProgressDto> _progress;
  StreamSubscription<Object?>? _native;

  @override
  Future<void> startPayment(StartPaymentRequestDto request) async {
    await _askNotificationPermission();
    await _invoke(PaymentChannel.startPayment, request.toMap());
  }

  @override
  Future<void> cancelPayment() => _invoke(PaymentChannel.cancelPayment);

  @override
  Stream<PaymentProgressDto> watchProgress() => _progress.stream;

  /// Ends the shared stream and the native subscription behind it.
  Future<void> dispose() {
    _closeNative();
    return _progress.close();
  }

  /// Asks, and ignores the answer. Not timed: the user may take a while.
  Future<void> _askNotificationPermission() async {
    try {
      await _methods.invokeMethod<Object?>(
        PaymentChannel.requestNotificationPermission,
      );
    } on PlatformException catch (error) {
      // Denial, or no way to ask, only means no notification. Start anyway, and say so.
      _logger.warning(
        'Asking for the notification permission failed with ${error.code}; '
        'starting the payment anyway.',
      );
    } on MissingPluginException {
      // No native side: startPayment fails as unsupported right after.
    }
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _methods
          .invokeMethod<Object?>(method, arguments)
          .timeout(callTimeout);
    } on PlatformException catch (error) {
      // The code and the method, never the message or the arguments.
      _logger.warning('Payment call "$method" failed with ${error.code}.');
      throw PlatformCallException(error.code, error.message);
    } on MissingPluginException {
      throw const UnsupportedException();
    } on TimeoutException {
      _logger.warning('Payment call "$method" did not answer in time.');
      throw const PlatformCallException(
        ChannelErrorCodes.unavailable,
        'The platform did not answer in time.',
      );
    }
  }

  void _openNative() {
    _native = _progressEvents.receiveBroadcastStream().listen(
      (event) {
        try {
          _progress.add(PaymentProgressDto.fromMap(event));
        } on MalformedPayloadException catch (error) {
          _logger.warning('A payment progress event was malformed.');
          _progress.addError(error);
        }
      },
      onError: (Object error) {
        _logger.warning(
          'The payment progress events failed '
          '(${error is PlatformException ? error.code : error.runtimeType}).',
        );
        _progress.addError(
          error is PlatformException
              ? PlatformCallException(error.code, error.message)
              : const UnsupportedException(),
        );
      },
    );
  }

  void _closeNative() {
    unawaited(_native?.cancel());
    _native = null;
  }
}
