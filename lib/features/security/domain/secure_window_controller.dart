import 'package:secure_payment_portal/core/error/result.dart';

/// Hides the app window from screenshots, the recents list and screen
/// recording while a sensitive screen is visible.
///
/// Calls are reference counted: the window is protected from the first
/// [enable] until [disable] has balanced every [enable], so one screen
/// leaving never unprotects another that is still visible.
abstract interface class SecureWindowController {
  Future<Result<void>> enable();

  Future<Result<void>> disable();
}
