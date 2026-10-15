import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/security/data/dtos/screen_recording_dto.dart';
import 'package:secure_payment_portal/features/security/data/dtos/security_status_dto.dart';

const MethodChannel securityMethodChannel = MethodChannel(
  SecurityChannel.methods,
);
const EventChannel securityRecordingChannel = EventChannel(
  SecurityChannel.recordingEvents,
);

/// The native side of the security channels, played in Dart over the mock binary
/// messenger, with the behaviour `docs/platform_channels.md` prescribes: a
/// reference-counted secure window, `windowProtection` reported from the real
/// state, `UNAVAILABLE` without an Activity, and the current recording state
/// replayed to a new listener.
///
/// It exists so the Dart half of the bridge (codec, error mapping, timeouts,
/// listener sharing) is tested against the same contract suite as the fake. The
/// Kotlin half has its own JVM tests; the two meet on a device.
final class NativeSecuritySimulator {
  NativeSecuritySimulator() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(securityMethodChannel, _onCall);
    messenger.setMockStreamHandler(
      securityRecordingChannel,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          listens++;
          _sink = events;
          events.success(_recording().toMap());
        },
        onCancel: (arguments) {
          cancels++;
          _sink = null;
        },
      ),
    );
  }

  // --- What the "device" is like. ---
  String root = DetectionWire.notDetected;
  List<String> rootSignals = [];
  String recording = DetectionWire.notDetected;
  bool hasActivity = true;

  /// When set, a call never gets an answer.
  bool hang = false;

  /// When set, the status reply is this instead of a valid map.
  Object? malformedStatus;

  // --- What the app did to it. ---
  int secureCount = 0;
  int listens = 0;
  int cancels = 0;
  final List<String> calls = [];

  MockStreamHandlerEventSink? _sink;

  bool get hasListener => _sink != null;

  ScreenRecordingDto _recording() =>
      ScreenRecordingDto(screenRecording: recording);

  /// The recording state changes on the device; the active listener hears it.
  void changeRecording(String wire) {
    recording = wire;
    _sink?.success(_recording().toMap());
  }

  void sendRaw(Object? event) => _sink?.success(event);

  void sendError() => _sink?.error(code: 'BOOM', message: 'native error');

  Future<Object?> _onCall(MethodCall call) async {
    calls.add(call.method);
    if (hang) return Completer<Object?>().future;
    switch (call.method) {
      case SecurityChannel.getSecurityStatus:
        if (malformedStatus != null) return malformedStatus;
        return SecurityStatusDto(
          root: root,
          rootSignals: rootSignals,
          screenRecording: recording,
          windowProtection: hasActivity && secureCount > 0
              ? WindowProtectionWire.active
              : WindowProtectionWire.inactive,
        ).toMap();
      case SecurityChannel.enableSecureWindow:
        if (!hasActivity) {
          throw PlatformException(
            code: ChannelErrorCodes.unavailable,
            message: 'There is no window to protect.',
          );
        }
        secureCount++;
        return null;
      case SecurityChannel.disableSecureWindow:
        if (secureCount > 0) secureCount--;
        return null;
      default:
        throw MissingPluginException();
    }
  }

  /// Removes the handlers, as if there were no native side.
  static void uninstall() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(securityMethodChannel, null);
    messenger.setMockStreamHandler(securityRecordingChannel, null);
  }
}
