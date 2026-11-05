import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/app_open.dart';

void main() {
  group('the version that is counted', () {
    test('is a release, without what a build for the browser adds', () {
      expect(releaseVersion('0.80.0'), '0.80.0');
      expect(releaseVersion('0.80.0-web'), '0.80.0');
      expect(releaseVersion('1.2'), '1.2');
      expect(releaseVersion('12.34.56.78'), '12.34.56.78');
    });

    test('is nothing for a build that is not a release', () {
      expect(releaseVersion('dev'), isNull);
      expect(releaseVersion('dev-web'), isNull);
      expect(releaseVersion(''), isNull);
      expect(releaseVersion('0.80.0-beta'), isNull);
      expect(releaseVersion('1.2.3.4.5'), isNull);
      expect(releaseVersion('1234.1'), isNull);
    });

    test('is something the database takes, which is what it is checked against there', () {
      final shape = RegExp(r'^[0-9]{1,3}(\.[0-9]{1,3}){0,3}$');
      for (final v in ['0.80.0', '0.80.0-web', '1.2']) {
        expect(shape.hasMatch(releaseVersion(v)!), isTrue, reason: v);
      }
    });
  });

  test('the platform is one of the ones the database knows', () {
    expect(['android', 'ios', 'web', 'windows', 'linux', 'macos'], contains(platformName()));
  });

  group('how often it is counted', () {
    test('once in half an hour, however often the app is opened', () {
      final throttle = OpenThrottle();
      final start = DateTime(2026, 10, 1, 12);
      expect(throttle.due(start), isTrue);
      expect(throttle.due(start.add(const Duration(minutes: 5))), isFalse);
      expect(throttle.due(start.add(const Duration(minutes: 29, seconds: 59))), isFalse);
      expect(throttle.due(start.add(const Duration(minutes: 30))), isTrue);
      expect(throttle.due(start.add(const Duration(minutes: 31))), isFalse, reason: 'counted from the last one');
    });

    test('a call that is not let through does not move the time', () {
      final throttle = OpenThrottle(const Duration(minutes: 10));
      final start = DateTime(2026, 10, 1, 12);
      expect(throttle.due(start), isTrue);
      expect(throttle.due(start.add(const Duration(minutes: 8))), isFalse);
      expect(throttle.due(start.add(const Duration(minutes: 10))), isTrue);
    });
  });
}
