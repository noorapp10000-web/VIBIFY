import 'package:flutter_test/flutter_test.dart';
import 'package:vibify/core/extensions/duration_extensions.dart';

void main() {
  group('DurationExtensions', () {
    test('shortFormatted: zero duration', () {
      expect(Duration.zero.shortFormatted, '00:00');
    });

    test('shortFormatted: less than a minute', () {
      expect(const Duration(seconds: 45).shortFormatted, '00:45');
    });

    test('shortFormatted: exactly one minute', () {
      expect(const Duration(minutes: 1).shortFormatted, '01:00');
    });

    test('shortFormatted: 3 minutes 30 seconds', () {
      expect(
        const Duration(minutes: 3, seconds: 30).shortFormatted,
        '03:30',
      );
    });

    test('formatted: under one hour', () {
      expect(
        const Duration(minutes: 12, seconds: 5).formatted,
        '12:05',
      );
    });

    test('formatted: over one hour', () {
      expect(
        const Duration(hours: 1, minutes: 2, seconds: 3).formatted,
        '01:02:03',
      );
    });
  });

  group('NullableDurationExtensions', () {
    test('formattedOrZero returns 00:00 for null', () {
      const Duration? d = null;
      expect(d.formattedOrZero, '00:00');
    });

    test('formattedOrZero returns formatted string for non-null', () {
      const Duration? d = Duration(minutes: 2, seconds: 15);
      expect(d.formattedOrZero, '02:15');
    });
  });
}
