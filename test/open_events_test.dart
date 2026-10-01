import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:tyria_codex/l10n/strings.dart';
import 'package:tyria_codex/screens/open_events_screen.dart' show openEventDuration;
import 'package:tyria_codex/state/open_events.dart';

Map<String, dynamic> row({
  String id = 'e1',
  String status = 'scheduled',
  int going = 2,
  int? max = 5,
  String start = '2026-10-01T18:00:00+00:00',
  int minutes = 120,
  String? mine,
}) =>
    {
      'id': id,
      'title': 'Wing 1 to 3',
      'description': 'Bring food.',
      'activity': 'raid',
      'language': 'en',
      'start_at': start,
      'duration_minutes': minutes,
      'max_participants': max,
      'organizer': 'Leo.1234',
      'mine': mine == 'yes',
      'going': going,
      'maybe': 1,
      'my_status': mine == 'going' ? 'going' : null,
      'status': status,
    };

void main() {
  group('an event', () {
    test('is read from what the database says', () {
      final e = OpenEvent.fromJson(row());
      expect(e.title, 'Wing 1 to 3');
      expect(e.organizer, 'Leo.1234');
      expect(e.activity, 'raid');
      expect(e.language, 'en');
      expect(e.durationMinutes, 120);
      expect(e.maxParticipants, 5);
      expect(e.going, 2);
      expect(e.maybe, 1);
      expect(e.mine, isFalse);
      expect(e.myStatus, isNull);
      expect(e.hidden, isFalse);
      expect(e.startAt.isUtc, isFalse, reason: 'shown in the player\'s own time');
    });

    test('says when it ends, whether it is full and how many places are left', () {
      final e = OpenEvent.fromJson(row());
      expect(e.endAt.difference(e.startAt), const Duration(hours: 2));
      expect(e.isFull, isFalse);
      expect(e.placesLeft, 3);
      expect(OpenEvent.fromJson(row(going: 5)).isFull, isTrue);
      expect(OpenEvent.fromJson(row(going: 5)).placesLeft, 0);
      expect(OpenEvent.fromJson(row(going: 9)).placesLeft, 0, reason: 'never below nothing');
      final unlimited = OpenEvent.fromJson(row(max: null, going: 500));
      expect(unlimited.isFull, isFalse);
      expect(unlimited.placesLeft, isNull);
    });

    test('is live between its start and its end, over after, and not live when it is cancelled', () {
      final e = OpenEvent.fromJson(row());
      final start = DateTime.parse('2026-10-01T18:00:00+00:00');
      expect(e.isLive(start.subtract(const Duration(minutes: 1))), isFalse);
      expect(e.isLive(start.add(const Duration(minutes: 30))), isTrue);
      expect(e.isLive(start.add(const Duration(hours: 3))), isFalse);
      expect(e.isOver(start.add(const Duration(hours: 3))), isTrue);
      expect(e.isOver(start.add(const Duration(minutes: 30))), isFalse);
      final cancelled = OpenEvent.fromJson(row(status: 'cancelled'));
      expect(cancelled.cancelled, isTrue);
      expect(cancelled.isLive(start.add(const Duration(minutes: 30))), isFalse);
    });

    test('keeps what the player said and whether it is theirs', () {
      final mine = OpenEvent.fromJson(row(mine: 'yes'));
      expect(mine.mine, isTrue);
      expect(OpenEvent.fromJson(row(mine: 'going')).myStatus, 'going');
    });

    test('survives a row with parts missing', () {
      final e = OpenEvent.fromJson({'id': 'x'});
      expect(e.title, '');
      expect(e.activity, 'other');
      expect(e.language, 'any');
      expect(e.maxParticipants, isNull);
      expect(e.going, 0);
      expect(e.status, 'scheduled');
    });
  });

  group('lists', () {
    test('are read, and what is not a list or not a row is nothing', () {
      expect(parseOpenEvents([row(id: 'a'), row(id: 'b')]).map((e) => e.id), ['a', 'b']);
      expect(parseOpenEvents([row(id: 'a'), 'junk', 7]).map((e) => e.id), ['a']);
      expect(parseOpenEvents(null), isEmpty);
      expect(parseOpenEvents({'error': 'x'}), isEmpty);
    });

    test('of who signed up are read by name and whether they are going', () {
      final roster = parseOpenRoster([
        {'name': 'Bo.5', 'status': 'going'},
        {'name': 'Cy.6', 'status': 'maybe'},
        'junk',
      ]);
      expect(roster, [(name: 'Bo.5', status: 'going'), (name: 'Cy.6', status: 'maybe')]);
      expect(parseOpenRoster(null), isEmpty);
    });
  });

  group('the filter', () {
    test('is nothing to begin with, and changes one thing at a time', () {
      const none = OpenEventsFilter();
      expect(none.activity, isNull);
      expect(none.language, isNull);
      final raids = none.withActivity('raid');
      expect(raids.activity, 'raid');
      final german = raids.withLanguage('de');
      expect(german.activity, 'raid', reason: 'the activity stays');
      expect(german.language, 'de');
      expect(german.withActivity(null).language, 'de', reason: 'and so does the language');
    });

    test('is equal to another of the same, so a list is not asked for again for nothing', () {
      expect(const OpenEventsFilter(activity: 'raid', language: 'de'),
          const OpenEventsFilter(activity: 'raid', language: 'de'));
      expect(const OpenEventsFilter(activity: 'raid').hashCode, const OpenEventsFilter(activity: 'raid').hashCode);
      expect(const OpenEventsFilter(activity: 'raid') == const OpenEventsFilter(activity: 'pvp'), isFalse);
    });
  });

  group('a refusal', () {
    test('is told in words for each reason the database gives', () {
      const reasons = {
        'banned': 'oe_err_banned',
        'no_account': 'oe_err_no_account',
        'bad_title': 'oe_err_title',
        'bad_description': 'oe_err_description',
        'start_in_past': 'oe_err_start_past',
        'start_too_far': 'oe_err_start_far',
        'bad_duration': 'oe_err_duration',
        'bad_capacity': 'oe_err_capacity',
        'too_many_open': 'oe_err_many_open',
        'too_many_today': 'oe_err_many_today',
        'event_gone': 'oe_err_gone',
        'own_event': 'oe_err_own',
        'event_full': 'oe_err_full',
        'below_going': 'oe_err_below',
        'already_reported': 'oe_err_reported',
      };
      reasons.forEach((hint, key) {
        expect(openEventErrorKey(OpenEventFailure(hint)), key, reason: hint);
        expect(openEventErrorKey(PostgrestException(message: 'x', hint: hint)), key,
            reason: 'straight from the database: $hint');
      });
    });

    test('that is not known, or has no reason, is told in general words', () {
      expect(openEventErrorKey(const OpenEventFailure('something_new')), 'oe_err_generic');
      expect(openEventErrorKey(PostgrestException(message: 'x')), 'oe_err_generic');
      expect(openEventErrorKey(StateError('offline')), 'oe_err_generic');
    });

    test('is explained in every language', () {
      const keys = [
        'oe_err_banned',
        'oe_err_no_account',
        'oe_err_title',
        'oe_err_description',
        'oe_err_start_past',
        'oe_err_start_far',
        'oe_err_duration',
        'oe_err_capacity',
        'oe_err_many_open',
        'oe_err_many_today',
        'oe_err_gone',
        'oe_err_own',
        'oe_err_full',
        'oe_err_below',
        'oe_err_reported',
        'oe_err_generic',
      ];
      for (final lang in AppLang.values) {
        final s = S(lang);
        for (final key in keys) {
          expect(s.t(key), isNot(key), reason: '$key in ${lang.code}');
        }
      }
    });
  });

  group('the words', () {
    test('every language has them, with the same blanks to fill', () {
      const filled = {
        'oe_by': ['name'],
        'oe_going': ['n'],
        'oe_maybe': ['n'],
        'oe_places': ['n', 'max'],
      };
      for (final lang in AppLang.values) {
        final s = S(lang);
        for (final entry in filled.entries) {
          final args = {for (final k in entry.value) k: 'VALUE_$k'};
          final text = s.t(entry.key, args);
          for (final k in entry.value) {
            expect(text, contains('VALUE_$k'), reason: '${entry.key} in ${lang.code}');
          }
          expect(text.contains('{'), isFalse, reason: 'a blank is left in ${entry.key} in ${lang.code}');
        }
        expect(s.t('public_events'), isNot('public_events'), reason: lang.code);
        for (final reason in ['spam', 'offensive', 'not_gw2', 'other']) {
          expect(s.t('oe_reason_$reason'), isNot('oe_reason_$reason'), reason: '$reason in ${lang.code}');
        }
      }
    });

    test('are in the languages an event can be run in, each with a name of its own', () {
      expect(openEventLanguages.first, 'any');
      expect(openEventLanguages.skip(1), AppLang.values.map((l) => l.code),
          reason: 'one for each language of the app, in its order');
    });
  });

  group('a length', () {
    test('is told in minutes, hours, or both', () {
      expect(openEventDuration(30), '30 min');
      expect(openEventDuration(60), '1 h');
      expect(openEventDuration(90), '1 h 30 min');
      expect(openEventDuration(120), '2 h');
      expect(openEventDuration(360), '6 h');
    });

    test('is one of the lengths the form offers, which the database takes', () {
      for (final d in openEventDurations) {
        expect(d, inInclusiveRange(15, 720));
      }
    });
  });
}
