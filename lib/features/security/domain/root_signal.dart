/// One independent heuristic that fired on the device.
///
/// Client-side root checks are heuristics that tools like Magisk DenyList can
/// bypass, so a clean result is "not detected", never "proven safe".
enum RootSignal {
  suBinary(isStrong: true),
  magiskArtifacts(isStrong: true),
  rootManagerPackage(isStrong: true),
  whichSu(isStrong: true),

  /// Common on emulators and developer builds, so weak on its own.
  testKeys(isStrong: false),

  /// Common on developer builds, so weak on its own.
  debuggableBuild(isStrong: false),

  /// A reason code this app version does not know (a newer native check). It
  /// counts as strong so that a signal is never silently weakened.
  unrecognized(isStrong: true);

  const RootSignal({required this.isStrong});

  /// Strong signals mean a rooted device. Weak ones only hint at it.
  final bool isStrong;
}
