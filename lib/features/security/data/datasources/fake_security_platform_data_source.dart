import 'package:secure_payment_portal/core/async/replay_latest.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/security/data/datasources/security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/data/dtos/screen_recording_dto.dart';
import 'package:secure_payment_portal/features/security/data/dtos/security_status_dto.dart';

/// A scripted device: no platform channel. Deterministic: the same latency and
/// state always give the same result. Use the `set…` methods to play a scenario
/// (a rooted device, a recording that starts) from a test or a demo.
final class FakeSecurityPlatformDataSource
    implements SecurityPlatformDataSource {
  FakeSecurityPlatformDataSource({
    SecurityStatusDto status = cleanDevice,
    this.latency = Duration.zero,
  }) : _status = status,
       _recording = ReplayLatest<ScreenRecordingDto>(
         ScreenRecordingDto(screenRecording: status.screenRecording),
       );

  /// Root checks clean and no screen recording. Window protection is not part
  /// of the script: like a real device, the fake reports it from the secure
  /// window calls it has received (see [getSecurityStatus]).
  static const SecurityStatusDto cleanDevice = SecurityStatusDto(
    root: DetectionWire.notDetected,
    rootSignals: [],
    screenRecording: DetectionWire.notDetected,
    windowProtection: WindowProtectionWire.inactive,
  );

  /// How long `getSecurityStatus` takes. Lets a UI show a scan in progress.
  final Duration latency;

  SecurityStatusDto _status;
  final ReplayLatest<ScreenRecordingDto> _recording;
  DataSourceException? _failure;
  bool _windowProtectionWorks = true;
  int _secureWindowCount = 0;

  /// How many `enableSecureWindow` calls are still unbalanced.
  int get secureWindowCount => _secureWindowCount;

  /// Whether `enableSecureWindow` can succeed. When false it fails the way a
  /// device without an Activity would, and the window stays unprotected.
  bool get windowProtectionWorks => _windowProtectionWorks;

  SecurityStatusDto get status => _status;

  /// Makes every call throw [failure], or work again when null.
  void failWith(DataSourceException? failure) => _failure = failure;

  void setRoot(String state, {List<String> signals = const []}) {
    _status = _status.copyWith(root: state, rootSignals: signals);
  }

  /// Changes the recording state and notifies listeners, like a real change.
  void setScreenRecording(String wireValue) {
    _status = _status.copyWith(screenRecording: wireValue);
    _recording.add(ScreenRecordingDto(screenRecording: wireValue));
  }

  void setWindowProtectionWorks(bool works) => _windowProtectionWorks = works;

  /// The scripted root and recording facts, plus the window protection this fake
  /// has actually applied: `active` while an enable is unbalanced.
  @override
  Future<SecurityStatusDto> getSecurityStatus() async {
    await _wait();
    _throwIfFailing();
    return _status.copyWith(
      windowProtection: _secureWindowCount > 0
          ? WindowProtectionWire.active
          : WindowProtectionWire.inactive,
    );
  }

  @override
  Stream<ScreenRecordingDto> watchScreenRecording() => _recording.stream;

  @override
  Future<void> enableSecureWindow() async {
    _throwIfFailing();
    if (!_windowProtectionWorks) {
      throw const PlatformCallException(ChannelErrorCodes.unavailable);
    }
    _secureWindowCount++;
  }

  @override
  Future<void> disableSecureWindow() async {
    _throwIfFailing();
    if (_secureWindowCount > 0) _secureWindowCount--;
  }

  Future<void> dispose() => _recording.close();

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  void _throwIfFailing() {
    final failure = _failure;
    if (failure != null) throw failure;
  }
}
