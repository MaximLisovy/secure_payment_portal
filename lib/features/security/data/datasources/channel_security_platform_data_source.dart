import 'dart:async';

import 'package:flutter/services.dart';
import 'package:secure_payment_portal/core/async/replay_latest.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/logging/logger.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/security/data/datasources/security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/data/dtos/screen_recording_dto.dart';
import 'package:secure_payment_portal/features/security/data/dtos/security_status_dto.dart';

/// The Kotlin `SecurityPlugin`, reached over its two channels. It honours the same
/// contract as the fake (the contract suite runs against both), so either sits
/// behind the repositories unchanged.
///
/// Failures are the typed `DataSourceException`s, never platform types:
/// - an error reply (`PlatformException`) becomes a [PlatformCallException];
/// - no native side at all (`MissingPluginException`: iOS, plain `flutter test`)
///   becomes an [UnsupportedException];
/// - a payload that is not in the documented shape is a
///   [MalformedPayloadException];
/// - no answer within [callTimeout] becomes `PlatformCallException(UNAVAILABLE)`.
///   A call that hangs would otherwise leave the app waiting for ever, and "no
///   answer" is as good a reason to refuse a payment as an error.
///
/// **One native listener.** The Android `EventChannel` keeps a single active
/// sink: a second `listen` replaces the first, and a `cancel` from the old
/// stream would then cancel the new one. So however many Dart listeners there
/// are, exactly one native subscription is open, opened for the first and closed
/// after the last. Each listener is replayed the latest state, as the contract
/// says, but never one from before the subscription was reopened.
///
/// The stream never carries an error. A malformed event, an error event, or a
/// missing native side is reported as `unknown`, which the policy handles.
final class ChannelSecurityPlatformDataSource
    implements SecurityPlatformDataSource {
  ChannelSecurityPlatformDataSource({
    required MethodChannel methods,
    required EventChannel recordingEvents,
    required Logger logger,
    this.callTimeout = const Duration(seconds: 5),
  }) : _methods = methods,
       _recordingEvents = recordingEvents,
       _logger = logger {
    _recordings = ReplayLatest<ScreenRecordingDto>.empty(
      onFirstListener: _openNative,
      onLastCancel: _closeNative,
      forgetOnLastCancel: true,
    );
  }

  static const ScreenRecordingDto _unknownRecording = ScreenRecordingDto(
    screenRecording: DetectionWire.unknown,
  );

  final MethodChannel _methods;
  final EventChannel _recordingEvents;
  final Logger _logger;

  /// How long a method call may take before it counts as unavailable.
  final Duration callTimeout;

  late final ReplayLatest<ScreenRecordingDto> _recordings;
  StreamSubscription<Object?>? _native;

  @override
  Future<SecurityStatusDto> getSecurityStatus() async {
    final reply = await _invoke(SecurityChannel.getSecurityStatus);
    return SecurityStatusDto.fromMap(reply);
  }

  @override
  Future<void> enableSecureWindow() async {
    await _invoke(SecurityChannel.enableSecureWindow);
  }

  @override
  Future<void> disableSecureWindow() async {
    await _invoke(SecurityChannel.disableSecureWindow);
  }

  @override
  Stream<ScreenRecordingDto> watchScreenRecording() => _recordings.stream;

  /// Ends the shared stream and the native subscription behind it.
  Future<void> dispose() {
    _closeNative();
    return _recordings.close();
  }

  Future<Object?> _invoke(String method) async {
    try {
      return await _methods.invokeMethod<Object?>(method).timeout(callTimeout);
    } on PlatformException catch (error) {
      // The code and the method, never the message or the arguments.
      _logger.warning('Security call "$method" failed with ${error.code}.');
      throw PlatformCallException(error.code, error.message);
    } on MissingPluginException {
      throw const UnsupportedException();
    } on TimeoutException {
      _logger.warning('Security call "$method" did not answer in time.');
      throw const PlatformCallException(
        ChannelErrorCodes.unavailable,
        'The platform did not answer in time.',
      );
    }
  }

  void _openNative() {
    _native = _recordingEvents.receiveBroadcastStream().listen(
      (event) => _recordings.add(_parse(event)),
      onError: (Object error) {
        _logger.warning(
          'The recording events failed (${_describe(error)}); reading it as unknown.',
        );
        _recordings.add(_unknownRecording);
      },
    );
  }

  void _closeNative() {
    unawaited(_native?.cancel());
    _native = null;
  }

  ScreenRecordingDto _parse(Object? event) {
    try {
      return ScreenRecordingDto.fromMap(event);
    } on MalformedPayloadException {
      _logger.warning(
        'A recording event was malformed; reading it as unknown.',
      );
      return _unknownRecording;
    }
  }

  /// A code or a type name: never the text of an error.
  static String _describe(Object error) =>
      error is PlatformException ? error.code : '${error.runtimeType}';
}
