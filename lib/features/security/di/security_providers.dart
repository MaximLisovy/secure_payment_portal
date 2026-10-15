import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/features/security/data/repositories/secure_window_controller_impl.dart';
import 'package:secure_payment_portal/features/security/data/repositories/security_status_repository_impl.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';
import 'package:secure_payment_portal/features/security/domain/secure_window_controller.dart';
import 'package:secure_payment_portal/features/security/domain/security_policy.dart';
import 'package:secure_payment_portal/features/security/domain/security_status_repository.dart';

// The public providers of the security feature, all typed by domain
// interfaces. Presentation and other features import these (through
// `security.dart`) and never the data layer.

final securityStatusRepositoryProvider = Provider<SecurityStatusRepository>(
  (ref) => SecurityStatusRepositoryImpl(
    ref.watch(securityPlatformDataSourceProvider),
  ),
);

final secureWindowControllerProvider = Provider<SecureWindowController>(
  (ref) =>
      SecureWindowControllerImpl(ref.watch(securityPlatformDataSourceProvider)),
);

/// The default policy. Override it to change what a device may do.
final securityPolicyProvider = Provider<SecurityPolicy>(
  (ref) => const SecurityPolicy(),
);
