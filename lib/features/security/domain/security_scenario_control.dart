/// A device a simulated security source can pretend to be.
enum DeviceScenario {
  /// Root checks run and find nothing.
  clean,

  /// Strong root signals: the policy blocks payment.
  rooted,

  /// Only weak signals (test keys): the default policy lets payment through.
  rootedWeakOnly,

  /// The root checks cannot run or cannot be trusted.
  rootUnverifiable,
}

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
}
