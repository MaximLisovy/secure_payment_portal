/// User-facing text, in one place so it can move to ARB/l10n later.
/// Brand-specific copy (names, promo text) belongs in the brand config instead.
abstract final class AppStrings {
  // Brand preview (temporary placeholder screen).
  static const previewColors = 'Color roles';
  static const previewShape = 'Shape';
  static const previewControls = 'Controls';
  static const previewDefaults = 'Material defaults';
  static const previewRows = 'Rows';
  static const previewMotion = 'Motion';

  static const roleBrandPrimary = 'Primary';
  static const roleBrandAccent = 'Accent';
  static const roleBrandOnSurface = 'On surface';
  static const roleSurfaceElevated = 'Elevated';
  static const roleSuccess = 'Success';
  static const roleDanger = 'Danger';
  static const roleScanGlow = 'Scan glow';

  static const radiusSm = 'Small';
  static const radiusMd = 'Medium';
  static const radiusLg = 'Large';
  static const cardLabel = 'Card';

  static const buttonFilled = 'Filled';
  static const buttonOutlined = 'Outlined';
  static const buttonText = 'Text';
  static const fieldLabel = 'Reference number';

  static const motionToggle = 'Animate';
  static const switchBrand = 'Switch brand';

  static String rowTitle(int number) => 'Row $number';

  /// The text for a `Failure.messageKey` or a `SecurityBlockReason.messageKey`.
  /// An unknown key reads as a generic problem instead of showing a raw key.
  static String message(String key) => switch (key) {
    'error.network' =>
      'We could not reach the service. Check your connection and try again.',
    'error.not_found' => 'We could not find this bill.',
    'error.invalid_data' =>
      'The service sent something we could not read. Please try again.',
    'error.platform' =>
      'Something went wrong on this device. Please try again.',
    'error.unsupported' => 'This is not available on this device.',
    'payment.declined' => 'The payment was declined.',
    'payment.in_progress' => 'A payment is already in progress.',
    'payment.invalid' => 'There is nothing valid to pay.',
    'payment.processing_failed' => 'The payment could not be completed.',
    'security.blocked.root_detected' =>
      'Payments are turned off because this device appears to be rooted.',
    'security.blocked.root_unverifiable' =>
      'We could not verify that this device is safe, so payments are turned off.',
    'security.blocked.screen_protection_unavailable' =>
      'Screen protection could not be turned on, so payment is paused.',
    'security.blocked.screen_recording' =>
      'Payment is paused while the screen is being recorded.',
    'security.blocked.recording_unverifiable' =>
      'We could not tell whether the screen is being recorded.',
    _ => 'Something went wrong. Please try again.',
  };
}
