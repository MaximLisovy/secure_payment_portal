import 'package:secure_payment_portal/features/security/domain/device_scenario.dart';

/// Lets a demo or a test play device scenarios on a simulated security source.
///
/// Only simulated sources implement it. A real source cannot, so code that holds
/// one is working with a simulation and needs no type check to know it.
abstract interface class SecurityScenarioControl {
  DeviceScenario get deviceScenario;

  void setDeviceScenario(DeviceScenario scenario);

  /// Whether a screen recording is in progress.
  bool get recordingActive;

  void setRecordingActive({required bool active});

  /// Whether the simulated device *reports* screen protection as active. It is
  /// a reading, like root and recording: it never touches the real window, whose
  /// `FLAG_SECURE` stays on in every mode. Turning it off lets a demo show the
  /// "screen protection unavailable" block without removing any protection.
  bool get screenProtectionAvailable;

  void setScreenProtectionAvailable({required bool available});

  /// How long reading the device takes. A longer reading keeps the security
  /// scan on screen longer, which a demo can use.
  Duration get checkDuration;

  void setCheckDuration(Duration duration);
}
