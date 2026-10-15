import 'package:secure_payment_portal/features/security/data/dtos/screen_recording_dto.dart';
import 'package:secure_payment_portal/features/security/data/dtos/security_status_dto.dart';

/// The platform side of device security. The fake and the channel-based
/// implementation honour the same contract, so either can sit behind the
/// repositories unchanged (the contract suite checks it).
///
/// Failures are thrown as `DataSourceException`s and never as platform types.
abstract interface class SecurityPlatformDataSource {
  /// A fresh read of the root checks and the current recording state.
  Future<SecurityStatusDto> getSecurityStatus();

  /// Emits the current recording state as soon as it is listened to, then each
  /// change. Every listener gets that replay.
  Stream<ScreenRecordingDto> watchScreenRecording();

  /// Reference counted: the window stays protected until every call has been
  /// balanced by a [disableSecureWindow].
  Future<void> enableSecureWindow();

  /// An extra call with nothing to balance is ignored.
  Future<void> disableSecureWindow();
}
