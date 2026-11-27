import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/guild_attendance.dart';

void main() {
  test('parses the rows of the attendance', () {
    final a = parseAttendance({
      'days': 90,
      'events': 4,
      'rows': [
        {
          'account_name': 'Leo.1234',
          'role': 'officer',
          'going': 3,
          'maybe': 1,
          'declined': 0,
          'waitlist': 0,
          'no_answer': 0,
          'last_going': '2026-11-20T19:00:00Z'
        },
        {'account_name': 'Mia.5678', 'role': 'member', 'going': 0, 'no_answer': 4},
      ],
    });
    expect(a.events, 4);
    expect(a.rows, hasLength(2));
    expect(a.rows.first.going, 3);
    expect(a.rows.first.lastGoing, isNotNull);
    expect(a.rows.last.noAnswer, 4);
    expect(a.rows.last.lastGoing, isNull);
  });

  test('takes nothing for an odd answer', () {
    expect(parseAttendance(null).rows, isEmpty);
  });
}
