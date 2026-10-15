import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/error/failure_mapper.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/features/security/data/datasources/security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/domain/secure_window_controller.dart';

/// Backed by the same platform data source as the status repository: one
/// native module, two small domain interfaces.
final class SecureWindowControllerImpl implements SecureWindowController {
  const SecureWindowControllerImpl(this._dataSource);

  final SecurityPlatformDataSource _dataSource;

  @override
  Future<Result<void>> enable() => _run(_dataSource.enableSecureWindow);

  @override
  Future<Result<void>> disable() => _run(_dataSource.disableSecureWindow);

  Future<Result<void>> _run(Future<void> Function() action) async {
    try {
      await action();
      return Success.unit;
    } on DataSourceException catch (error) {
      return Err(failureFromError(error));
    }
  }
}
