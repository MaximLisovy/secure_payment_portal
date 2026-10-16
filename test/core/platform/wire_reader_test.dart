import 'package:flutter_test/flutter_test.dart';
import 'package:secure_payment_portal/core/error/data_exceptions.dart';
import 'package:secure_payment_portal/core/platform/channel_contract.dart';
import 'package:secure_payment_portal/core/platform/wire_reader.dart';

Matcher _malformed([Matcher? message]) => throwsA(
  isA<MalformedPayloadException>().having(
    (e) => e.message,
    'message',
    message ?? isNotEmpty,
  ),
);

void main() {
  group('WireReader', () {
    test('validates inclusive numeric ranges without echoing values', () {
      for (final value in [-1, 101, 9223372036854775807]) {
        final reader = WireReader({'percent': value}, what: 'event');
        expect(
          () => reader.requireInt('percent', min: 0, max: 100),
          _malformed(allOf(contains('percent'), isNot(contains('$value')))),
        );
      }
      for (final value in [0, 100]) {
        final reader = WireReader({'percent': value}, what: 'event');
        expect(reader.requireInt('percent', min: 0, max: 100), value);
      }
      final reader = WireReader({'percent': -1}, what: 'event');
      expect(() => reader.optionalInt('percent', min: 0), _malformed());
    });

    test('epoch milliseconds fit DateTime on both sides of the epoch', () {
      for (final value in [
        -WireReader.maxEpochMilliseconds,
        WireReader.maxEpochMilliseconds,
      ]) {
        final reader = WireReader({'completedAtMillis': value}, what: 'event');
        expect(reader.requireEpochMilliseconds('completedAtMillis'), value);
        expect(
          DateTime.fromMillisecondsSinceEpoch(
            value,
            isUtc: true,
          ).millisecondsSinceEpoch,
          value,
        );
      }
      for (final value in [
        -WireReader.maxEpochMilliseconds - 1,
        WireReader.maxEpochMilliseconds + 1,
        9223372036854775807,
      ]) {
        expect(
          () => WireReader({
            'completedAtMillis': value,
          }, what: 'event').requireEpochMilliseconds('completedAtMillis'),
          _malformed(),
        );
      }
    });

    test('rejects a payload that is not a map', () {
      expect(
        () => WireReader('x', what: 'status'),
        _malformed(contains('status')),
      );
      expect(() => WireReader(null, what: 'status'), _malformed());
      expect(() => WireReader(<Object?>[], what: 'status'), _malformed());
    });

    test('reads required and optional strings and ints', () {
      final reader = WireReader(<Object?, Object?>{
        's': 'text',
        'i': 7,
        'os': 'maybe',
        'oi': 3,
      }, what: 'p');

      expect(reader.requireString('s'), 'text');
      expect(reader.requireInt('i'), 7);
      expect(reader.optionalString('os'), 'maybe');
      expect(reader.optionalInt('oi'), 3);
      expect(reader.optionalString('missing'), isNull);
      expect(reader.optionalInt('missing'), isNull);
    });

    test('names the field when a required value is missing or mistyped', () {
      final reader = WireReader(<Object?, Object?>{
        'n': 1,
        'd': 1.5,
        's': 'x',
      }, what: 'p');

      expect(
        () => reader.requireString('absent'),
        _malformed(contains('absent')),
      );
      expect(() => reader.requireString('n'), _malformed(contains('"n"')));
      expect(() => reader.requireInt('s'), _malformed(contains('"s"')));
      expect(() => reader.requireInt('d'), _malformed(contains('"d"')));
      expect(() => reader.optionalString('n'), _malformed(contains('"n"')));
      expect(() => reader.optionalInt('s'), _malformed(contains('"s"')));
    });

    test('never echoes a value into the error message', () {
      final reader = WireReader(<Object?, Object?>{'secret': 4242}, what: 'p');

      expect(
        () => reader.requireString('secret'),
        _malformed(isNot(contains('4242'))),
      );
    });

    test('reads a list of strings and rejects other lists', () {
      final reader = WireReader(<Object?, Object?>{
        'ok': <Object?>['a', 'b'],
        'empty': <Object?>[],
        'mixed': <Object?>['a', 1],
        'notList': 'a',
      }, what: 'p');

      expect(reader.requireStringList('ok'), ['a', 'b']);
      expect(reader.requireStringList('empty'), isEmpty);
      expect(() => reader.requireStringList('mixed'), _malformed());
      expect(() => reader.requireStringList('notList'), _malformed());
      expect(() => reader.requireStringList('absent'), _malformed());
    });

    test('reads a list of any elements, to be read one by one', () {
      final reader = WireReader(<Object?, Object?>{
        'items': <Object?>[
          <Object?, Object?>{'a': 1},
          'x',
        ],
        'notList': 'a',
      }, what: 'p');

      expect(reader.requireList('items'), hasLength(2));
      expect(() => reader.requireList('notList'), _malformed());
      expect(() => reader.requireList('absent'), _malformed());
    });

    test('accepts the supported schema version only', () {
      WireReader(<Object?, Object?>{
        ChannelContract.keySchemaVersion: ChannelContract.schemaVersion,
      }, what: 'p').requireSchemaVersion();

      expect(
        () => WireReader(<Object?, Object?>{
          ChannelContract.keySchemaVersion: ChannelContract.schemaVersion + 1,
        }, what: 'p').requireSchemaVersion(),
        _malformed(contains('schemaVersion')),
      );
      expect(
        () =>
            WireReader(<Object?, Object?>{}, what: 'p').requireSchemaVersion(),
        _malformed(),
      );
    });
  });
}
