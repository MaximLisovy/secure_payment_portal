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
