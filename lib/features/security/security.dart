// Public barrel of the security feature: its domain, its providers (typed by
// domain interfaces) and the `SecureScreen` widget with its state. Another
// feature's `di/` and `presentation/` import this file; its `domain/` imports
// `security_domain.dart` instead, which is pure Dart. Never `data/`.
export 'package:secure_payment_portal/features/security/di/security_providers.dart';
export 'package:secure_payment_portal/features/security/presentation/secure_screen.dart';
export 'package:secure_payment_portal/features/security/presentation/secure_window_notifier.dart';
export 'package:secure_payment_portal/features/security/presentation/secure_window_state.dart';
export 'package:secure_payment_portal/features/security/security_domain.dart';
