import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/l10n/strings.dart';
import 'package:wondrous_compass/screens/guild_events_screen.dart';
import 'package:wondrous_compass/state/community.dart';
import 'package:wondrous_compass/state/guild_events.dart';

GuildEvent _event({String creator = 'someone', String guild = 'g1'}) => GuildEvent.fromRow({
      'id': 'e1',
      'guild_id': guild,
      'creator_id': creator,
      'series_id': null,
      'title': 'Raid night',
      'description': '',
      'activity': 'raid',
      'start_at': '2026-10-01T18:00:00+00:00',
      'duration_minutes': 90,
      'max_participants': 10,
      'status': 'scheduled',
      'version': 3,
      'guilds': {'name': 'Mistwalkers', 'tag': 'MIST'},
    });

void main() {
  test('an event row reads with its guild and end time', () {
    final e = _event();
    expect(e.guildTag, 'MIST');
    expect(e.version, 3);
    expect(e.cancelled, isFalse);
    expect(e.endAt.difference(e.startAt), const Duration(minutes: 90));
    expect(e.startAt.isUtc, isFalse, reason: 'shown in local time');
  });

  test('the creator and the guild\'s leaders and officers may manage an event', () {
    const member = MyGuild('g1', 'Mistwalkers', 'MIST', 'member');
    const officer = MyGuild('g1', 'Mistwalkers', 'MIST', 'officer');
    const elsewhere = MyGuild('g2', 'Other', 'OTH', 'leader');
    expect(canManageEvent(_event(creator: 'me'), 'me', const [member]), isTrue);
    expect(canManageEvent(_event(), 'me', const [officer]), isTrue);
    expect(canManageEvent(_event(), 'me', const [member]), isFalse);
    expect(canManageEvent(_event(), 'me', const [elsewhere]), isFalse);
  });

  test('event times read with the weekday in the app language', () {
    final monday = DateTime(2026, 9, 28, 21, 5);
    expect(eventWhen(const S(AppLang.en), monday), 'Mon 28.09 · 21:05');
    expect(eventWhen(const S(AppLang.tr), monday), 'Pzt 28.09 · 21:05');
  });

  test('every activity and role has an icon and a name', () {
    const s = S(AppLang.de);
    for (final a in eventActivities) {
      expect(s.t('activity_$a'), isNot('activity_$a'));
    }
    for (final r in eventRoleKeys) {
      expect(s.t('role_$r'), isNot('role_$r'));
    }
    for (final preset in eventRolePresets.values) {
      expect(preset.keys.every(eventRoleKeys.contains), isTrue);
    }
  });

  test('the professions offered are the nine the backend accepts', () {
    expect(eventProfessions.length, 9);
    expect(eventProfessions.toSet().length, 9);
    expect(eventProfessions, containsAll(['Guardian', 'Necromancer', 'Revenant']));
  });

  test('only iana zone names are sent for weekly events', () {
    for (final ok in [
      'Europe/Istanbul',
      'America/Argentina/Buenos_Aires',
      'UTC',
      'Etc/GMT-3',
      'America/Port-au-Prince'
    ]) {
      expect(isIanaZone(ok), isTrue, reason: ok);
    }
    for (final bad in ['EET', 'GMT+3', '+03:00', '', 'europe/istanbul', 'Europe/']) {
      expect(isIanaZone(bad), isFalse, reason: bad);
    }
  });

  test('the event knows the account it was created with', () {
    expect(_event().organizer, isNull, reason: 'older events have none');
    final row = {
      'id': 'e1',
      'guild_id': 'g1',
      'creator_id': 'someone',
      'organizer_name': 'Zed.1234',
      'title': 'Raid',
      'start_at': '2026-10-01T18:00:00+00:00',
      'guilds': {'name': 'Mistwalkers', 'tag': 'MIST'},
    };
    expect(GuildEvent.fromRow(row).organizer, 'Zed.1234');
  });

  group('the accounts that may organize', () {
    const accounts = [
      GuildAccount('g1', 'a-mia', 'Mia.3', 'officer'),
      GuildAccount('g1', 'a-zed', 'Zed.1', 'leader'),
      GuildAccount('g1', 'a-abe', 'Abe.2', 'member'),
      GuildAccount('g2', 'a-abe', 'Abe.2', 'officer'),
      GuildAccount('g3', 'a-abe', 'Abe.2', 'member'),
    ];

    test('the leader comes first, then officers by name, members never', () {
      expect(organizersFor(accounts, 'g1').map((a) => a.accountName), ['Zed.1', 'Mia.3']);
    });

    test('roles are per account and guild', () {
      // abe is an officer of g2 and only a member of g1 and g3
      expect(organizersFor(accounts, 'g2').map((a) => a.accountName), ['Abe.2']);
      expect(organizersFor(accounts, 'g3'), isEmpty);
      expect(organizersFor(accounts, 'unknown'), isEmpty);
    });

    test('nothing to choose from when there are no accounts', () {
      expect(organizersFor(const [], 'g1'), isEmpty);
    });
  });

  group('signing up with an account', () {
    const accounts = [
      GuildAccount('g1', 'a-mia', 'Mia.3', 'member'),
      GuildAccount('g1', 'a-zed', 'Zed.1', 'leader'),
      GuildAccount('g1', 'a-abe', 'Abe.2', 'officer'),
      GuildAccount('g2', 'a-abe', 'Abe.2', 'member'),
    ];

    test('every account of the player in the guild is offered, the highest role first', () {
      expect(accountsIn(accounts, 'g1').map((a) => a.accountName), ['Zed.1', 'Abe.2', 'Mia.3']);
      expect(accountsIn(accounts, 'g2').map((a) => a.accountName), ['Abe.2']);
      expect(accountsIn(accounts, 'g3'), isEmpty);
    });

    test('an account chosen before is kept while it is still one of the player\'s in the guild', () {
      expect(accountToKeep('a-mia', accountsIn(accounts, 'g1')), 'a-mia');
      // chosen in another guild, or unlinked since: a choice is due again
      expect(accountToKeep('a-mia', accountsIn(accounts, 'g2')), isNull);
      expect(accountToKeep('gone', accountsIn(accounts, 'g1')), isNull);
      expect(accountToKeep(null, accountsIn(accounts, 'g1')), isNull);
    });

    test('the roster gives a player their own account id and nobody else\'s', () {
      // what the server sends: account_id only in the caller's row
      final own = EventParticipant(
        userId: 'me',
        name: 'Abe.2',
        avatarUrl: null,
        status: 'going',
        role: 'dps',
        joinedAt: DateTime.utc(2026, 10, 1),
        accountId: 'a-abe',
      );
      final other = EventParticipant(
        userId: 'other',
        name: 'Zed.1',
        avatarUrl: null,
        status: 'going',
        role: 'dps',
        joinedAt: DateTime.utc(2026, 10, 1),
      );
      expect(own.accountId, 'a-abe');
      expect(other.accountId, isNull);
    });
  });

  group('discord only events and flex roles', () {
    Map<String, dynamic> row(Map<String, dynamic> extra) => {
          'id': 'e1',
          'guild_id': 'g1',
          'creator_id': 'someone',
          'title': 'Raid',
          'start_at': '2026-10-01T18:00:00+00:00',
          'guilds': {'name': 'Mistwalkers', 'tag': 'MIST'},
          ...extra,
        };

    test('an event is open to the app unless the server says it is for Discord', () {
      expect(GuildEvent.fromRow(row({})).discordOnly, isFalse, reason: 'older rows have no such column');
      expect(GuildEvent.fromRow(row({'discord_only': false})).discordOnly, isFalse);
      expect(GuildEvent.fromRow(row({'discord_only': true})).discordOnly, isTrue);
    });

    test('flex roles are read from json, and nonsense is none', () {
      expect(stringList(['healer', 'dps']), ['healer', 'dps']);
      expect(stringList(null), isEmpty);
      expect(stringList('healer'), isEmpty);
      expect(stringList(<dynamic>[]), isEmpty);
    });

    test('a player has no flex roles until they name some', () {
      final p = EventParticipant(
        userId: 'me',
        name: 'Abe.2',
        avatarUrl: null,
        status: 'going',
        role: 'dps',
        joinedAt: DateTime.utc(2026, 10, 1),
      );
      expect(p.flex, isEmpty);
    });

    test('the new refusals are explained, in every language', () {
      for (final lang in AppLang.values) {
        final s = S(lang);
        for (final code in ['discord_only', 'role_restricted', 'not_signed_up', 'bad_flex']) {
          final text = eventFailureText(s, EventFailure(code));
          expect(text, isNot('event_err_$code'), reason: '${lang.code} $code');
          expect(text, isNot(contains('(')), reason: 'a known code has its own text');
        }
        // too many changes in an hour, which the database counts per player
        expect(eventFailureText(s, const EventFailure('rate_limited')), s.t('err_rate_limited'), reason: lang.code);
      }
    });
  });
}
