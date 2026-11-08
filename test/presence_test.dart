import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/presence.dart';

void main() {
  test('a run of the app has a random id the server takes, a new one each time', () {
    final a = newPresenceSession(Random(1));
    expect(RegExp(r'^[A-Za-z0-9]{24}$').hasMatch(a), isTrue);
    expect(newPresenceSession(Random(2)), isNot(a));
  });

  test('the announcement is read from the server, nothing when there is none', () {
    final a = Announcement.fromJson({'text': ' Maintenance at 22:00 ', 'kind': 'maintenance', 'set_at': '2026-11-08T16:00:00Z'})!;
    expect(a.text, 'Maintenance at 22:00');
    expect(a.maintenance, isTrue);
    expect(a.id, '2026-11-08T16:00:00Z|Maintenance at 22:00');
    expect(Announcement.fromJson({'text': 'hi'})!.maintenance, isFalse);
    expect(Announcement.fromJson(null), isNull);
    expect(Announcement.fromJson({'text': '  '}), isNull);
  });
}
