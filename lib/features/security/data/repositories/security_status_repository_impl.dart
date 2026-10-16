import 'dart:async';

import 'package:secure_payment_portal/core/error/failure_mapper.dart';
import 'package:secure_payment_portal/core/error/result.dart';
import 'package:secure_payment_portal/core/logging/logger.dart';
import 'package:secure_payment_portal/features/security/data/datasources/security_platform_data_source.dart';
import 'package:secure_payment_portal/features/security/data/dtos/screen_recording_dto.dart';
import 'package:secure_payment_portal/features/security/data/mappers/security_status_mapper.dart';
import 'package:secure_payment_portal/features/security/domain/security_status.dart';
import 'package:secure_payment_portal/features/security/domain/security_status_repository.dart';

final class SecurityStatusRepositoryImpl implements SecurityStatusRepository {
  const SecurityStatusRepositoryImpl(this._dataSource, {required Logger logger})
    : _logger = logger;

  final SecurityPlatformDataSource _dataSource;
  final Logger _logger;

  @override
  Future<Result<SecurityStatus>> getStatus() async {
    try {
      final dto = await _dataSource.getSecurityStatus();
      return Success(SecurityStatusMapper.toEntity(dto));
    } on Object catch (error, stackTrace) {
      return Err(
        failureFromError(error, logger: _logger, stackTrace: stackTrace),
      );
    }
  }

  /// Built on a `StreamController`, not `async*`: cancelling an `async*` stream
  /// that is waiting on a quiet inner stream does not take effect until the next
  /// event, which would keep the native listener registered. Here `onCancel`
  /// releases it at once.
  @override
  Stream<SecurityStatus> watchStatus() {
    late final StreamController<SecurityStatus> controller;
    StreamSubscription<Detection>? recordings;
    var cancelled = false;

    Future<void> start() async {
      // A failed first read is `unknown`, so the policy decides, not luck.
      var status = switch (await getStatus()) {
        Success<SecurityStatus>(:final value) => value,
        Err<SecurityStatus>() => SecurityStatus.unknown,
      };
      if (cancelled) return;
      controller.add(status);

      // The data source replays the current recording state on listen, so a
      // change that happened during the first read is not lost.
      recordings = _recordingStates().listen((recording) {
        if (recording == status.screenRecording) return;
        status = status.copyWith(screenRecording: recording);
        controller.add(status);
      }, onDone: controller.close);
    }

    controller = StreamController<SecurityStatus>(
      onListen: () => unawaited(start()),
      onCancel: () {
        cancelled = true;
        return recordings?.cancel();
      },
    );
    return controller.stream;
  }

  /// Recording states, with anything unreadable (an error event, a malformed
  /// payload) turned into `unknown` instead of an error.
  Stream<Detection> _recordingStates() {
    final Stream<ScreenRecordingDto> source;
    try {
      source = _dataSource.watchScreenRecording();
    } on Object catch (error, stackTrace) {
      failureFromError(error, logger: _logger, stackTrace: stackTrace);
      return Stream.value(Detection.unknown);
    }
    return source.transform(
      StreamTransformer<ScreenRecordingDto, Detection>.fromHandlers(
        handleData: (dto, sink) {
          try {
            sink.add(
              SecurityStatusMapper.detectionFromWire(dto.screenRecording),
            );
          } on Object {
            sink.add(Detection.unknown);
          }
        },
        handleError: (error, stackTrace, sink) => sink.add(Detection.unknown),
      ),
    );
  }
}
