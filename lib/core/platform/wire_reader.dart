import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';

/// Typed, validating access to a flat wire map (a channel or JSON payload).
///
/// Anything missing or of the wrong type throws a [MalformedPayloadException]
/// that names the field, never its value, so payloads that may carry sensitive
/// data are not echoed into errors.
final class WireReader {
  factory WireReader(Object? raw, {required String what}) {
    if (raw is! Map<Object?, Object?>) {
      throw MalformedPayloadException('$what is not a map');
    }
    return WireReader._(raw, what);
  }

  WireReader._(this._map, this._what);

  final Map<Object?, Object?> _map;
  final String _what;

  /// Requires the payload's `schemaVersion` to be the one this app understands.
  void requireSchemaVersion() {
    final version = requireInt(ChannelContract.keySchemaVersion);
    if (version != ChannelContract.schemaVersion) {
      throw MalformedPayloadException(
        '$_what has an unsupported schemaVersion',
      );
    }
  }

  String requireString(String key, {bool nonEmpty = false}) {
    final value = _map[key];
    if (value is String && (!nonEmpty || value.trim().isNotEmpty)) return value;
    throw _bad(key, nonEmpty ? 'a non-empty string' : 'a string');
  }

  String? optionalString(String key) {
    final value = _map[key];
    if (value == null) return null;
    if (value is String) return value;
    throw _bad(key, 'a string or absent');
  }

  static const minSignedInt = -9223372036854775808;
  static const maxSignedInt = 9223372036854775807;

  // DateTime supports at most 100,000,000 days either side of the Unix epoch.
  // https://api.dart.dev/dart-core/DateTime-class.html
  static const maxEpochMilliseconds = 8640000000000000;

  /// Also used by mappers for DTOs constructed without going through a map.
  static int validatedInt(
    int value, {
    required String field,
    int min = minSignedInt,
    int max = maxSignedInt,
  }) {
    if (value < min || value > max) {
      throw MalformedPayloadException('"$field" is outside its valid range');
    }
    return value;
  }

  int requireEpochMilliseconds(String key) =>
      requireInt(key, min: -maxEpochMilliseconds, max: maxEpochMilliseconds);

  int requireInt(String key, {int min = minSignedInt, int max = maxSignedInt}) {
    final value = _map[key];
    if (value is int) {
      return validatedInt(value, field: key, min: min, max: max);
    }
    throw _bad(key, 'an int');
  }

  int? optionalInt(
    String key, {
    int min = minSignedInt,
    int max = maxSignedInt,
  }) {
    final value = _map[key];
    if (value == null) return null;
    if (value is int) {
      return validatedInt(value, field: key, min: min, max: max);
    }
    throw _bad(key, 'an int or absent');
  }

  /// A list whose elements are read one by one (e.g. with a nested [WireReader]).
  List<Object?> requireList(String key) {
    final value = _map[key];
    if (value is List<Object?>) return value;
    throw _bad(key, 'a list');
  }

  List<String> requireStringList(String key) {
    final value = _map[key];
    if (value is List<Object?> && value.every((item) => item is String)) {
      return List<String>.of(value.cast<String>());
    }
    throw _bad(key, 'a list of strings');
  }

  MalformedPayloadException _bad(String key, String expected) {
    return MalformedPayloadException('$_what: "$key" must be $expected');
  }
}
