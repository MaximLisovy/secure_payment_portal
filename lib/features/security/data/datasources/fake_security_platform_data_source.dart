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

  /// Root checks clean and no screen recording.
  static const SecurityStatusDto cleanDevice = SecurityStatusDto(
    root: DetectionWire.notDetected,
    rootSignals: [],
    screenRecording: DetectionWire.notDetected,
  );

  /// How long `getSecurityStatus` takes. Lets a UI show a scan in progress.
  final Duration latency;

  SecurityStatusDto _status;
  final ReplayLatest<ScreenRecordingDto> _recording;
  DataSourceException? _failure;
  int _secureWindowCount = 0;

  /// How many `enableSecureWindow` calls are still unbalanced.
  int get secureWindowCount => _secureWindowCount;

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

  @override
  Future<SecurityStatusDto> getSecurityStatus() async {
    await _wait();
    _throwIfFailing();
    return _status;
  }

  @override
  Stream<ScreenRecordingDto> watchScreenRecording() => _recording.stream;

  @override
  Future<void> enableSecureWindow() async {
    _throwIfFailing();
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
