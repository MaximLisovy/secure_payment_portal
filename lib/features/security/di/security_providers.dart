import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_payment_portal/core/simulation/source_mode.dart';
import 'package:secure_payment_portal/features/security/data/repositories/secure_window_controller_impl.dart';
import 'package:secure_payment_portal/features/security/data/repositories/security_status_repository_impl.dart';
import 'package:secure_payment_portal/features/security/di/security_data_source_providers.dart';
import 'package:secure_payment_portal/features/security/domain/secure_window_controller.dart';
import 'package:secure_payment_portal/features/security/domain/security_policy.dart';
import 'package:secure_payment_portal/features/security/domain/security_scenario_control.dart';
import 'package:secure_payment_portal/features/security/domain/security_status_repository.dart';

// The public providers of the security feature, all typed by domain
// interfaces. Presentation and other features import these (through
// `security.dart`) and never the data layer.

final securityStatusRepositoryProvider = Provider<SecurityStatusRepository>(
  (ref) => SecurityStatusRepositoryImpl(
    ref.watch(securityPlatformDataSourceProvider),
  ),
);

/// Always on the real source, in every mode (see
/// `secureWindowPlatformDataSourceProvider`).
final secureWindowControllerProvider = Provider<SecureWindowController>(
  (ref) => SecureWindowControllerImpl(
    ref.watch(secureWindowPlatformDataSourceProvider),
  ),
);

/// The default policy. Override it to change what a device may do.
final securityPolicyProvider = Provider<SecurityPolicy>(
  (ref) => const SecurityPolicy(),
);

/// The controls of the simulated device, or null when the feature runs on a real
/// one. There is nothing to downcast: only the simulation implements the
/// interface, and a null here is the app's way of knowing it is not simulated.
final securityScenarioControlProvider = Provider<SecurityScenarioControl?>(
  (ref) => ref.watch(securitySourceModeProvider) == SourceMode.simulated
      ? ref.watch(simulatedSecurityPlatformDataSourceProvider)
      : null,
);
