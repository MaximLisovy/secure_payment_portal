// Public barrel of the payment feature: the config types a brand declares, the
// page the app shows, the section registry a new brand extends, and the
// controls a debug build uses to steer the simulated sources.
// `brands/` imports this file and nothing else from the feature.
export 'package:secure_payment_portal/features/payment/di/payment_data_source_providers.dart'
    show paymentSourceModeProvider;
export 'package:secure_payment_portal/features/payment/di/payment_providers.dart'
    show
        billBackendControlProvider,
        paymentScenarioControlProvider,
        paymentIdProvider;
export 'package:secure_payment_portal/features/payment/domain/bill_backend_control.dart';
export 'package:secure_payment_portal/features/payment/domain/payment_scenario.dart';
export 'package:secure_payment_portal/features/payment/presentation/config/payment_screen_config.dart';
export 'package:secure_payment_portal/features/payment/presentation/config/payment_section_spec.dart';
export 'package:secure_payment_portal/features/payment/presentation/pages/payment_confirmation_page.dart';
export 'package:secure_payment_portal/features/payment/presentation/sections/payment_section_registry.dart';
export 'package:secure_payment_portal/features/payment/presentation/state/payment_flow_providers.dart'
    show paymentInProgressProvider;
export 'package:secure_payment_portal/features/payment/presentation/state/restart_payment_flow.dart';
export 'package:secure_payment_portal/features/payment/presentation/state/scan_dwell_provider.dart';
