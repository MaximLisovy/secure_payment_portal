import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:secure_payment_portal/app/brand/brand_providers.dart';
import 'package:secure_payment_portal/app/di/reduced_motion_provider.dart';
import 'package:secure_payment_portal/core/design_system/scan/scan_style.dart';
import 'package:secure_payment_portal/features/payment/payment.dart';

/// Makes the payment flow hold the device-check verdict for one revolution of
/// the active brand's scan: the sweep is always seen going all the way round,
/// even when the check itself takes a fraction of a second.
///
/// It follows the brand, so a brand switch changes it, and it is zero for a
/// user who asked for reduced motion: there is no sweep to wait for. The app
/// adds it next to `rootOverrides`; the feature default (no wait) stays for
/// tests that want the verdict at once.
List<Override> scanDwellOverrides() => [
  scanDwellProvider.overrideWith((ref) {
    if (ref.watch(reducedMotionProvider)) return Duration.zero;
    final motion = ref.watch(
      activeBrandProvider.select((brand) => brand.tokens.motion),
    );
    return ScanStyle.periodFor(motion);
  }),
];
