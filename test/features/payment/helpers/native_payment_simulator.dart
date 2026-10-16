import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/payment_progress_dto.dart';
import 'package:secure_payment_portal/features/payment/data/dtos/start_payment_request_dto.dart';

/// Text the native side puts in every error message. A log must never repeat it:
/// a message could carry anything, so only the code is ever logged.
const nativeCanary = 'card 4111 1111 1111 1111';

const MethodChannel paymentMethodChannel = MethodChannel(
  PaymentChannel.methods,
);
const EventChannel paymentProgressChannel = EventChannel(
  PaymentChannel.progressEvents,
);

/// The Kotlin foreground service played in Dart over the mock binary messenger,
/// with the behaviour `docs/platform_channels.md` prescribes: one payment at a
/// time, `INVALID_ARGS` for an amount that is not positive, progress from 0, a
/// terminal state that stays until the next start, an idempotent cancel, and the
/// current state replayed on listen. It uses timers only, so it runs under
/// `fakeAsync`, which is what the payment contract suite requires.
///
/// It exists so the Dart half of the bridge (codec, error mapping, timeouts,
/// listener sharing, the permission step) is tested against the same contract
/// suite as the fake. The Kotlin half has its own JVM tests; the two meet on a
/// device.
final class NativePaymentSimulator {
  NativePaymentSimulator({
    this.stepDelay = const Duration(milliseconds: 100),
    this.steps = 4,
  }) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(paymentMethodChannel, _onCall);
    messenger.setMockStreamHandler(
      paymentProgressChannel,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          listens++;
          _sink = events;
          events.success(_current.toMap());
        },
        onCancel: (arguments) {
          cancels++;
          _sink = null;
        },
      ),
    );
  }

  final Duration stepDelay;
  final int steps;

  // --- What the "device" does. ---

  /// What `requestNotificationPermission` answers.
  String permissionAnswer = NotificationPermissionWire.granted;

  /// How long the permission prompt stays up before it is answered.
  Duration permissionDelay = Duration.zero;

  /// When set, the permission call fails with an error reply.
  bool permissionFails = false;

  /// When set, `startPayment` fails with this error code.
  String? startFailsWith;

  /// When set, `startPayment` is never answered.
  bool hangOnStart = false;

  // --- What the app did to it. ---
  int listens = 0;
  int cancels = 0;
  final List<String> calls = [];
  int _transactions = 0;

  PaymentProgressDto _current = PaymentProgressDto.idle;
  StartPaymentRequestDto? _running;
  int _step = 0;
  Timer? _timer;
  MockStreamHandlerEventSink? _sink;

  bool get hasListener => _sink != null;

  void sendRaw(Object? event) => _sink?.success(event);

  void sendError() => _sink?.error(code: 'BOOM', message: nativeCanary);

  Future<Object?> _onCall(MethodCall call) async {
    calls.add(call.method);
    switch (call.method) {
      case PaymentChannel.requestNotificationPermission:
        if (permissionDelay > Duration.zero) {
          await Future<void>.delayed(permissionDelay);
        }
        if (permissionFails) {
          throw PlatformException(code: 'INTERNAL', message: nativeCanary);
        }
        return permissionAnswer;
      case PaymentChannel.startPayment:
        if (hangOnStart) return Completer<Object?>().future;
        final failure = startFailsWith;
        if (failure != null) {
          throw PlatformException(code: failure, message: nativeCanary);
        }
        final StartPaymentRequestDto request;
        try {
          request = StartPaymentRequestDto.fromMap(call.arguments);
        } on Object {
          throw PlatformException(code: ChannelErrorCodes.invalidArgs);
        }
        if (request.amountMinor <= 0) {
          throw PlatformException(code: ChannelErrorCodes.invalidArgs);
        }
        if (_running != null) {
          throw PlatformException(code: ChannelErrorCodes.alreadyRunning);
        }
        _running = request;
        _step = 0;
        _emit(PaymentProgressDto.running(request.paymentId, 0));
        _timer = Timer.periodic(stepDelay, (_) => _tick());
        return null;
      case PaymentChannel.cancelPayment:
        if (_running != null) _finish(PaymentProgressDto.cancelled);
        return null;
      default:
        throw MissingPluginException();
    }
  }

  void _tick() {
    final request = _running;
    if (request == null) return;
    _step++;
    if (_step <= steps) {
      _emit(
        PaymentProgressDto.running(request.paymentId, _step * 100 ~/ steps),
      );
      return;
    }
    _transactions++;
    _finish(
      PaymentProgressDto.succeeded(
        paymentId: request.paymentId,
        transactionId: 'NATIVE-TX-$_transactions',
        amountMinor: request.amountMinor,
        currency: request.currency,
        completedAtMillis: 1700000000000,
      ),
    );
  }

  void _finish(PaymentProgressDto terminal) {
    _timer?.cancel();
    _timer = null;
    _running = null;
    _emit(terminal);
  }

  void _emit(PaymentProgressDto dto) {
    _current = dto;
    _sink?.success(dto.toMap());
  }

  /// How long a started payment needs to reach its terminal state.
  Duration get completionTime => stepDelay * (steps + 1);

  /// Removes the handlers, as if there were no native side.
  static void uninstall() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(paymentMethodChannel, null);
    messenger.setMockStreamHandler(paymentProgressChannel, null);
  }
}
