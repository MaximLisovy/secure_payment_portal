import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/core/platform/wire_reader.dart';

/// One event of the screen recording `EventChannel`.
final class ScreenRecordingDto extends Equatable {
  const ScreenRecordingDto({required this.screenRecording});

  /// Throws `MalformedPayloadException` if [raw] is not the documented shape.
  factory ScreenRecordingDto.fromMap(Object? raw) {
    final reader = WireReader(raw, what: 'screen recording event')
      ..requireSchemaVersion();
    return ScreenRecordingDto(
      screenRecording: reader.requireString(SecurityChannel.keyScreenRecording),
    );
  }

  /// A [DetectionWire] value.
  final String screenRecording;

  Map<String, Object?> toMap() => {
    ChannelContract.keySchemaVersion: ChannelContract.schemaVersion,
    SecurityChannel.keyScreenRecording: screenRecording,
  };

  @override
  List<Object?> get props => [screenRecording];
}
