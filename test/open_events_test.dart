import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:wondrous_compass/l10n/strings.dart';
import 'package:wondrous_compass/screens/open_event_labels.dart' show openEventDuration;
import 'package:wondrous_compass/state/open_events.dart';

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
      expect(roster, [
        (name: 'Bo.5', status: 'going', role: null, profession: null),
        (name: 'Cy.6', status: 'maybe', role: null, profession: null),
      ]);
      expect(parseOpenRoster(null), isEmpty);
    });

    test('with the role and the profession each comes as', () {
      final roster = parseOpenRoster([
        {'name': 'Bo.5', 'status': 'going', 'role': 'healer', 'profession': 'Guardian'},
      ]);
      expect(roster.single.role, 'healer');
      expect(roster.single.profession, 'Guardian');
    });

    test('an event has its composition, with how many take each role, and what the player comes as', () {
      final e = OpenEvent.fromJson({
        'id': 'e1',
        'title': 'Squad',
        'roles': [
          {'role': 'healer', 'slots': 2, 'taken': 1},
          {'role': 'dps', 'slots': 6, 'taken': 0},
        ],
        'my_role': 'healer',
        'my_profession': 'Guardian',
      });
      expect(e.hasRoles, isTrue);
      expect(e.totalSlots, 8);
      expect(e.roles.first, (role: 'healer', slots: 2, taken: 1));
      expect(e.myRole, 'healer');
      expect(e.myProfession, 'Guardian');
      expect(OpenEvent.fromJson({'id': 'e2'}).hasRoles, isFalse);
      expect(OpenEvent.fromJson({'id': 'e2'}).myRole, isNull);
    });

    test('and what a role that cannot be had says', () {
      for (final hint in ['role_required', 'profession_required', 'bad_profession', 'role_full', 'bad_roles']) {
        expect(openEventErrorKey(OpenEventFailure(hint)), isNot('oe_err_generic'), reason: hint);
      }
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
      expect(openEventErrorKey(const PostgrestException(message: 'x')), 'oe_err_generic');
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

  group('a region', () {
    test('is read from an event, and an event that does not say is for all', () {
      final e = OpenEvent.fromJson({
        ...row(),
        'region': 'na',
        'tags': ['meta', 'casual'],
        'map_id': 1209
      });
      expect(e.region, 'na');
      expect(e.tags, ['meta', 'casual']);
      expect(e.mapId, 1209);
      final plain = OpenEvent.fromJson(row());
      expect(plain.region, 'all');
      expect(plain.tags, isEmpty);
      expect(plain.mapId, isNull);
      expect(OpenEvent.fromJson({...row(), 'tags': 'meta'}).tags, isEmpty, reason: 'a list that is not one is none');
    });

    test('and a tag narrow the list, each on its own', () {
      final eu = const OpenEventsFilter(activity: 'raid').withRegion('eu');
      expect(eu.region, 'eu');
      expect(eu.activity, 'raid', reason: 'the activity stays');
      final tagged = eu.withTag('casual');
      expect(tagged.tag, 'casual');
      expect(tagged.region, 'eu');
      expect(tagged.withRegion(null).tag, 'casual');
      expect(tagged.withTag(null).region, 'eu');
      expect(const OpenEventsFilter(region: 'eu', tag: 'meta'), const OpenEventsFilter(region: 'eu', tag: 'meta'));
      expect(const OpenEventsFilter(region: 'eu') == const OpenEventsFilter(region: 'na'), isFalse);
      expect(const OpenEventsFilter(tag: 'meta') == const OpenEventsFilter(tag: 'casual'), isFalse);
      expect(const OpenEventsFilter(region: 'eu').hashCode, const OpenEventsFilter(region: 'eu').hashCode);
    });

    test('is told in words when it is wrong, an event is about to be made for one, or a tag or a map is none', () {
      const reasons = {
        'wrong_region': 'oe_err_wrong_region',
        'bad_region': 'oe_err_region',
        'bad_tags': 'oe_err_tags',
        'bad_map': 'oe_err_map',
      };
      for (final r in reasons.entries) {
        expect(openEventErrorKey(OpenEventFailure(r.key)), r.value);
        expect(openEventErrorKey(PostgrestException(message: 'x', hint: r.key)), r.value);
      }
    });

    test('is a player\'s own: the regions of the accounts the game has placed, and what they may make and join', () {
      final both = MyRegions.fromJson({
        'accounts': [
          {'id': 'a1', 'name': 'Leo.1', 'region': 'eu'},
          {'id': 'a2', 'name': 'Leo.NA', 'region': 'na'},
          {'id': 'a3', 'name': 'Leo.3', 'region': null},
        ],
      });
      expect(both.regions, {'eu', 'na'}, reason: 'an account with no region is in none');
      expect(both.makeable, ['all', 'eu', 'na']);
      expect(both.forRegion('eu').map((a) => a.name), ['Leo.1']);
      expect(both.forRegion('all').map((a) => a.name), ['Leo.1', 'Leo.NA', 'Leo.3'],
          reason: 'any takes part in one for all');
      expect(both.forRegion('na').single.id, 'a2');

      final unplaced = MyRegions.fromJson({
        'accounts': [
          {'id': 'a1', 'name': 'Leo.1', 'region': null},
        ],
      });
      expect(unplaced.hasAccount, isTrue);
      expect(unplaced.regions, isEmpty);
      expect(unplaced.makeable, ['all'], reason: 'with no region known, only an event for all');
      expect(unplaced.forRegion('eu'), isEmpty);

      for (final nothing in [
        null,
        'x',
        <String, dynamic>{},
        {'accounts': 'x'}
      ]) {
        final none = MyRegions.fromJson(nothing);
        expect(none.hasAccount, isFalse);
        expect(none.makeable, ['all']);
      }
    });

    test('and its kinds have words in every language, the map one with its blank', () {
      for (final lang in AppLang.values) {
        final s = S(lang);
        for (final r in openEventRegions) {
          expect(s.t('oe_region_$r'), isNot('oe_region_$r'), reason: '$r in ${lang.code}');
        }
        for (final t in openEventTags) {
          expect(s.t('oe_tag_$t'), isNot('oe_tag_$t'), reason: '$t in ${lang.code}');
        }
        for (final k in openEventActivities) {
          expect(s.t('activity_$k'), isNot('activity_$k'), reason: '$k in ${lang.code}');
        }
        for (final key in [
          'oe_region',
          'oe_region_note',
          'oe_region_unknown',
          'oe_tags',
          'oe_tag_any',
          'oe_map',
          'oe_err_map',
          'oe_err_region',
          'oe_err_wrong_region',
          'oe_err_tags',
          'oe_join_as',
          'oe_err_role_required',
          'oe_err_profession',
          'oe_err_role_full',
          'oe_err_roles',
          'oe_places_roles',
          'oe_come_as',
          'oe_profession_btn',
          'oe_role_full',
          'oe_roles_title',
          'oe_roles_body',
          'oe_roles_join',
          'oe_roles_none',
        ]) {
          expect(s.t(key), isNot(key), reason: '$key in ${lang.code}');
        }
        final pill = s.t('oe_map_pill', {'id': 'VALUE_id'});
        expect(pill, contains('VALUE_id'), reason: lang.code);
        expect(pill.contains('{'), isFalse, reason: lang.code);
      }
    });

    test('has the worldboss kind, the three regions and six tags', () {
      expect(openEventActivities, contains('worldboss'));
      expect(openEventRegions, ['eu', 'na', 'all']);
      expect(openEventTags.length, 6);
    });
  });
}
