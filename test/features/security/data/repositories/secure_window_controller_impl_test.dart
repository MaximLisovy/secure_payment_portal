import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/error/failure.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/features/security/data/datasources/security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/data/repositories/secure_window_controller_impl.dart';

class _MockDataSource extends Mock implements SecurityPlatformDataSource {}

void main() {
  late _MockDataSource dataSource;
  late SecureWindowControllerImpl controller;

  setUp(() {
    dataSource = _MockDataSource();
    controller = SecureWindowControllerImpl(dataSource);
  });

  test('enable asks the platform to protect the window', () async {
    when(() => dataSource.enableSecureWindow()).thenAnswer((_) async {});

    final result = await controller.enable();

    expect(result, Success.unit);
    verify(() => dataSource.enableSecureWindow()).called(1);
    verifyNever(() => dataSource.disableSecureWindow());
  });

  test('disable asks the platform to release the window', () async {
    when(() => dataSource.disableSecureWindow()).thenAnswer((_) async {});

    final result = await controller.disable();

    expect(result, Success.unit);
    verify(() => dataSource.disableSecureWindow()).called(1);
    verifyNever(() => dataSource.enableSecureWindow());
  });

  final failures = <(String, DataSourceException, Failure)>[
    (
      'platform error',
      const PlatformCallException(ChannelErrorCodes.unavailable),
      const PlatformFailure(ChannelErrorCodes.unavailable),
    ),
    ('unsupported', const UnsupportedException(), const UnsupportedFailure()),
  ];
  for (final (name, thrown, expected) in failures) {
    test('maps a $name on enable to $expected', () async {
      when(() => dataSource.enableSecureWindow()).thenThrow(thrown);

      expect(await controller.enable(), Err<void>(expected));
    });

    test('maps a $name on disable to $expected', () async {
      when(() => dataSource.disableSecureWindow()).thenThrow(thrown);

      expect(await controller.disable(), Err<void>(expected));
    });
  }

  test('does not swallow a programming error', () async {
    when(() => dataSource.enableSecureWindow()).thenThrow(StateError('bug'));

    await expectLater(controller.enable(), throwsStateError);
  });
}
