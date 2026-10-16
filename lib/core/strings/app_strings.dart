/// User-facing text, in one place so it can move to ARB/l10n later.
/// Brand-specific copy (names, promo text) belongs in the brand config instead.
abstract final class AppStrings {
  // Debug tooling.
  static const switchBrand = 'Switch brand';
  static const simulatedBadge = 'SIMULATED';
  static const simulatedBadgeHint =
      'Some of this app is running on a simulation, not on real services.';
  static const demoScenarios = 'Demo scenarios';
  static const demoIntro =
      'Debug and profile builds. Pick what is real and what is simulated, and play '
      'situations the real device or backend would be hard to put in.';
  static const demoSourcesLocked =
      'Sources cannot be switched while a payment is in progress.';
  static const demoSecuritySection = 'Device security';
  static const demoReportTitle = 'Device reports';
  static const demoReportRoot = 'Root';
  static const demoReportRecording = 'Screen recording';
  static const demoReportWindow = 'Window protection';
  static const demoReportReading = 'Reading the device…';
  static const demoReportRefresh = 'Read again';
  static const demoReportDetected = 'Detected';
  static const demoReportNotDetected = 'Not detected';
  static const demoReportUnknown = 'Unknown';
  static const demoReportActive = 'Active';
  static const demoReportInactive = 'Inactive';
  static const demoPaymentSection = 'Payment processing';
  static const demoBillSection = 'Bill backend';
  static const demoSourceReal = 'Real';
  static const demoSourceSimulated = 'Simulated';
  static const demoDevice = 'Device';
  static const demoRecording = 'Screen recording in progress';
  static const demoScreenProtection = 'Screen protection available';
  static const demoPaymentEnds = 'Payment ends';
  static const demoBackendOnline = 'Backend online';
  static const demoRestart = 'Restart payment';
  static const demoCheckTakes = 'Device check takes';
  static const demoDisplaySection = 'Display';
  static const demoPerformanceOverlay = 'Performance overlay';
  static const frameStatsTitle = 'Frame timings · rolling window';
  static const frameStatsBuild = 'Build';
  static const frameStatsRaster = 'Raster';
  static const frameStatsMs = 'ms';
  static const frameStatsP50 = 'p50';
  static const frameStatsP90 = 'p90';
  static const frameStatsP99 = 'p99';
  static const frameStatsWorst = 'Worst';
  static const frameStatsReset = 'Reset frame statistics';
  static String frameStatsCounts(int total, int window) =>
      'Frames since reset: $total · Window: $window / 600';
  static String frameStatsRefreshRate(double hz) =>
      'Display reports: ${hz.toStringAsFixed(0)} Hz';

  static const demoDeviceClean = 'Clean';
  static const demoDeviceRooted = 'Rooted';
  static const demoDeviceRootedWeak = 'Rooted (weak signs)';
  static const demoDeviceRootUnverifiable = 'Cannot verify root';
  static const demoPaymentSucceeds = 'Succeeds';
  static const demoPaymentDeclined = 'Is declined';
  static const demoPaymentFails = 'Fails while processing';

  // The payment screen.
  static const summaryTotal = 'Total';
  static const billBreakdownTitle = 'Bill breakdown';
  static const detailsLoading = 'Loading your bill…';
  static const protectingScreen = 'Preparing a protected screen…';
  static const securityChecking = 'Checking this device…';
  static const securityVerified = 'No root indicators found';
  static const checkAgain = 'Check again';
  static const tryAgain = 'Try again';
  static const confirming = 'Starting payment…';
  static const processingTitle = 'Processing your payment';
  static const paymentStatusUnavailable =
      'Payment status is unavailable on this device, so payments are turned off.';
  static const checkingPaymentStatus = 'Checking payment status…';
  static const paymentStatusUnconfirmed =
      "We couldn't confirm the payment status";
  static const paymentStatusGuidance =
      'Check your payment history or contact support before making another payment. '
      'You can still request cancellation while we wait for an update.';
  static const paymentStatusCheckingHint =
      'The payment may still be processing. Please wait before paying again.';
  static const cancellationStatusUnknown =
      'We could not confirm cancellation. You can request cancellation again.';
  static const cancel = 'Cancel';
  static const cancelling = 'Cancelling…';
  static const cancellationFailed =
      'Could not cancel. Your payment is still processing. Try again.';
  static const paymentSuccessful = 'Payment successful';
  static const paymentFailed = 'Payment failed';
  static const paymentCancelled = 'Payment cancelled';
  static const receiptMerchant = 'Paid to';
  static const receiptAmount = 'Amount';
  static const receiptTransaction = 'Transaction';
  static const receiptTime = 'Completed';
  static const repeatDemoPayment = 'Repeat demo payment';

  static String payAction(String amount) => 'Pay $amount';

  static String percentLabel(int percent) => '$percent%';

  static String progressSemantics(int percent) => '$percent percent complete';

  /// A length of time for the demo panel: "5 s", "1.5 s".
  static String demoSeconds(Duration duration) {
    final seconds = duration.inMilliseconds / Duration.millisecondsPerSecond;
    return '${seconds == seconds.roundToDouble() ? seconds.round() : seconds} s';
  }

  /// Extra guidance under a block, for the reasons that lift by themselves.
  static String? blockedHint(String key) => switch (key) {
    'security.blocked.screen_recording' =>
      'This continues by itself when the recording stops.',
    _ => null,
  };

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
    'error.unexpected' => 'Something unexpected happened. Please try again.',
    'payment.outcome_unknown' => paymentStatusUnconfirmed,
    'payment.declined' => 'The payment was declined.',
    'payment.in_progress' => 'A payment is already in progress.',
    'payment.confirmation_obsolete' => 'This confirmation is no longer active.',
    'payment.invalid' => 'There is nothing valid to pay.',
    'payment.start_not_allowed' => 'Open the app to pay.',
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
