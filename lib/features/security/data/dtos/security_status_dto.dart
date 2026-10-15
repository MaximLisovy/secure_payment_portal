import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/core/platform/wire_reader.dart';

/// The `getSecurityStatus` reply, exactly as it crosses the channel: strings
/// and a list of strings. The mapper turns it into a `SecurityStatus`.
final class SecurityStatusDto extends Equatable {
  const SecurityStatusDto({
    required this.root,
    required this.rootSignals,
    required this.screenRecording,
    required this.windowProtection,
  });

  /// Throws `MalformedPayloadException` if [raw] is not the documented shape.
  factory SecurityStatusDto.fromMap(Object? raw) {
    final reader = WireReader(raw, what: 'security status')
      ..requireSchemaVersion();
    return SecurityStatusDto(
      root: reader.requireString(SecurityChannel.keyRoot),
      rootSignals: reader.requireStringList(SecurityChannel.keyRootSignals),
      screenRecording: reader.requireString(SecurityChannel.keyScreenRecording),
      windowProtection: reader.requireString(
        SecurityChannel.keyWindowProtection,
      ),
    );
  }

  /// A [DetectionWire] value.
  final String root;

  /// Reason codes ([RootReasonCodes]); non-empty exactly when [root] is detected.
  final List<String> rootSignals;

  /// A [DetectionWire] value.
  final String screenRecording;

  /// A [WindowProtectionWire] value: whether the window is hidden from capture.
  final String windowProtection;

  Map<String, Object?> toMap() => {
    ChannelContract.keySchemaVersion: ChannelContract.schemaVersion,
    SecurityChannel.keyRoot: root,
    SecurityChannel.keyRootSignals: rootSignals,
    SecurityChannel.keyScreenRecording: screenRecording,
    SecurityChannel.keyWindowProtection: windowProtection,
  };

  SecurityStatusDto copyWith({
    String? root,
    List<String>? rootSignals,
    String? screenRecording,
    String? windowProtection,
  }) {
    return SecurityStatusDto(
      root: root ?? this.root,
      rootSignals: rootSignals ?? this.rootSignals,
      screenRecording: screenRecording ?? this.screenRecording,
      windowProtection: windowProtection ?? this.windowProtection,
    );
  }

  @override
  List<Object?> get props => [
    root,
    rootSignals,
    screenRecording,
    windowProtection,
  ];
}
