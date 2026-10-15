/// User-facing text, in one place so it can move to ARB/l10n later.
/// Brand-specific copy (names, promo text) belongs in the brand config instead.
abstract final class AppStrings {
  // Brand preview (temporary placeholder screen).
  static const previewColors = 'Color roles';
  static const previewShape = 'Shape';
  static const previewControls = 'Controls';
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
}
