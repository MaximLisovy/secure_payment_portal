import 'package:secure_payment_portal/core/async/replay_latest.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/security/data/datasources/security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/data/dtos/screen_recording_dto.dart';
import 'package:secure_payment_portal/features/security/data/dtos/security_status_dto.dart';
import 'package:secure_payment_portal/features/security/domain/security_scenario_control.dart';

/// A scripted device: no platform channel. Deterministic: the same latency and
/// state always give the same result. Use the `set…` methods to play a scenario
/// (a rooted device, a recording that starts) from a test or a demo.
///
/// By default it is a whole device, window included: it counts the secure window
/// calls it receives and reports protection from them, which is what the tests
/// of the window logic need. With [scriptedWindow] it is only a source of
/// *readings*: the window calls do nothing and the protection it reports is a
/// script ([setScreenProtectionAvailable]). That is how the simulation runs in
/// the app, where the real window is protected through the real source and the
/// simulation never touches it.
final class FakeSecurityPlatformDataSource
    implements SecurityPlatformDataSource, SecurityScenarioControl {
  FakeSecurityPlatformDataSource({
    SecurityStatusDto status = cleanDevice,
    this.latency = Duration.zero,
    this.windowLatency = Duration.zero,
    this.scriptedWindow = false,
  }) : _status = status,
       _recording = ReplayLatest<ScreenRecordingDto>(
         ScreenRecordingDto(screenRecording: status.screenRecording),
       );

  /// Root checks clean and no screen recording. The window protection in this
  /// constant is a placeholder: [getSecurityStatus] replaces it, from the window
  /// calls received (a whole device) or from the script ([scriptedWindow]).
  static const SecurityStatusDto cleanDevice = SecurityStatusDto(
    root: DetectionWire.notDetected,
    rootSignals: [],
    screenRecording: DetectionWire.notDetected,
    windowProtection: WindowProtectionWire.inactive,
  );

  /// How long `getSecurityStatus` takes. Lets a UI show a scan in progress.
  final Duration latency;

  /// How long `enableSecureWindow` takes to answer. Lets a test or a demo show a
  /// screen whose protection has been asked for but not yet confirmed.
  final Duration windowLatency;

  /// The window is not simulated by requests: `enableSecureWindow` and
  /// `disableSecureWindow` do nothing, and the reported protection comes from
  /// [screenProtectionAvailable].
  final bool scriptedWindow;

  SecurityStatusDto _status;
  final ReplayLatest<ScreenRecordingDto> _recording;
  DataSourceException? _failure;
  bool _windowProtectionWorks = true;
  DeviceScenario _deviceScenario = DeviceScenario.clean;
  int _secureWindowCount = 0;

  /// How many `enableSecureWindow` calls are still unbalanced.
  int get secureWindowCount => _secureWindowCount;

  /// Whether the device can protect its window. For a whole device, when false
  /// `enableSecureWindow` fails the way a device without an Activity would, and
  /// the window stays unprotected. With [scriptedWindow], when false the status
  /// reports the window as unprotected.
  @override
  bool get screenProtectionAvailable => _windowProtectionWorks;

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

  @override
  void setScreenProtectionAvailable({required bool available}) =>
      _windowProtectionWorks = available;

  @override
  DeviceScenario get deviceScenario => _deviceScenario;

  @override
  void setDeviceScenario(DeviceScenario scenario) {
    _deviceScenario = scenario;
    switch (scenario) {
      case DeviceScenario.clean:
        setRoot(DetectionWire.notDetected);
      case DeviceScenario.rooted:
        setRoot(
          DetectionWire.detected,
          signals: [RootReasonCodes.suBinary, RootReasonCodes.magiskArtifacts],
        );
      case DeviceScenario.rootedWeakOnly:
        setRoot(DetectionWire.detected, signals: [RootReasonCodes.testKeys]);
      case DeviceScenario.rootUnverifiable:
        setRoot(DetectionWire.unknown);
    }
  }

  @override
  bool get recordingActive => _status.screenRecording == DetectionWire.detected;

  @override
  void setRecordingActive({required bool active}) => setScreenRecording(
    active ? DetectionWire.detected : DetectionWire.notDetected,
  );

  /// The scripted root and recording facts, plus the window protection this fake
  /// has actually applied: `active` while an enable is unbalanced.
  @override
  Future<SecurityStatusDto> getSecurityStatus() async {
    await _wait();
    _throwIfFailing();
    final protected = scriptedWindow
        ? _windowProtectionWorks
        : _secureWindowCount > 0;
    return _status.copyWith(
      windowProtection: protected
          ? WindowProtectionWire.active
          : WindowProtectionWire.inactive,
    );
  }

  @override
  Stream<ScreenRecordingDto> watchScreenRecording() => _recording.stream;

  @override
  Future<void> enableSecureWindow() async {
    if (windowLatency > Duration.zero) {
      await Future<void>.delayed(windowLatency);
    }
    _throwIfFailing();
    if (scriptedWindow) return;
    if (!_windowProtectionWorks) {
      throw const PlatformCallException(ChannelErrorCodes.unavailable);
    }
    _secureWindowCount++;
  }

  @override
  Future<void> disableSecureWindow() async {
    _throwIfFailing();
    if (scriptedWindow) return;
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
