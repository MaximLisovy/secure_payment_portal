import 'package:secure_payment_portal/core/error/failure_mapper.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/core/logging/logger.dart';
import 'package:secure_payment_portal/features/security/data/datasources/security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/domain/secure_window_controller.dart';

/// Backed by the same platform data source as the status repository: one
/// native module, two small domain interfaces.
final class SecureWindowControllerImpl implements SecureWindowController {
  const SecureWindowControllerImpl(this._dataSource, {required Logger logger})
    : _logger = logger;

  final SecurityPlatformDataSource _dataSource;
  final Logger _logger;

  @override
  Future<Result<void>> enable() => _run(_dataSource.enableSecureWindow);

  @override
  Future<Result<void>> disable() => _run(_dataSource.disableSecureWindow);

  Future<Result<void>> _run(Future<void> Function() action) async {
    try {
      await action();
      return Success.unit;
    } on Object catch (error, stackTrace) {
      return Err(
        failureFromError(error, logger: _logger, stackTrace: stackTrace),
      );
    }
  }
}
