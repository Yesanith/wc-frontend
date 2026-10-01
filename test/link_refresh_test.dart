import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/l10n/strings.dart';
import 'package:tyria_codex/state/community.dart';
import 'package:tyria_codex/state/guild_events.dart';
import 'package:tyria_codex/state/link_refresh.dart';
import 'package:tyria_codex/state/news.dart';
import 'package:tyria_codex/state/open_events.dart' show MyRegions;

void main() {
  group('when the link is refreshed', () {
    final now = DateTime(2026, 10, 1, 12);

    test('never done is always due', () {
      expect(linkRefreshDue(null, now, leads: true), isTrue);
      expect(linkRefreshDue(null, now, leads: false), isTrue);
    });

    test('a guild leader is refreshed every half hour, so the guild stays current', () {
      expect(linkRefreshDue(now.subtract(const Duration(minutes: 29)), now, leads: true), isFalse);
      expect(linkRefreshDue(now.subtract(const Duration(minutes: 30)), now, leads: true), isTrue);
    });

    test('anybody else twice a day, enough to keep the membership counted', () {
      expect(linkRefreshDue(now.subtract(const Duration(hours: 11, minutes: 59)), now, leads: false), isFalse);
      expect(linkRefreshDue(now.subtract(const Duration(hours: 12)), now, leads: false), isTrue);
      expect(linkRefreshEvery(leads: false) < const Duration(days: 30), isTrue);
    });
  });

  group('an account the game has not placed in a region', () {
    test('is refreshed at once, not when the refresh is due', () {
      const placed = (id: 'a', name: 'Leo.1', region: 'eu');
      const unplaced = (id: 'b', name: 'Leo.2', region: null);
      expect(regionMissing(const MyRegions(accounts: [placed])), isFalse);
      expect(regionMissing(const MyRegions(accounts: [placed, unplaced])), isTrue);
      expect(regionMissing(const MyRegions(accounts: [unplaced])), isTrue);
      expect(regionMissing(const MyRegions()), isFalse, reason: 'nobody linked, nothing to refresh');
    });
  });

  group('what the game tells about a guild', () {
    test('the details are read from the row', () {
      final d = GuildDetails.fromRow({
        'level': 42,
        'motd': 'Raids on Friday',
        'member_count': 87,
        'member_capacity': 500,
        'details_synced_at': '2026-10-01T10:30:00+00:00',
      });
      expect(d.level, 42);
      expect(d.motd, 'Raids on Friday');
      expect(d.memberCount, 87);
      expect(d.memberCapacity, 500);
      expect(d.syncedAt, DateTime.utc(2026, 10, 1, 10, 30));
      expect(d.known, isTrue);
    });

    test('a guild its leader never shared is not known, and shows nothing made up', () {
      final d = GuildDetails.fromRow({
        'level': null,
        'motd': null,
        'member_count': null,
        'member_capacity': null,
        'details_synced_at': null,
      });
      expect(d.known, isFalse);
      expect(d.level, isNull);
      expect(d.motd, '');
      expect(d.memberCount, isNull);
    });

    test('numbers that come as decimals are whole numbers', () {
      expect(GuildDetails.fromRow({'level': 42.0, 'member_count': 87.9}).level, 42);
      expect(GuildDetails.fromRow({'level': 'many'}).level, isNull);
    });

    test('a role is by hand only when the backend says so', () {
      RosterMember member(Object? manual) =>
          RosterMember.fromRow({'user_id': 'u1', 'account_name': 'Mira.2', 'role': 'officer', 'manual': manual});
      expect(member(true).manual, isTrue);
      expect(member(false).manual, isFalse);
      expect(member(null).manual, isFalse, reason: 'an older backend');
      expect(member('yes').manual, isFalse);
    });

    test('the roster shows the game\'s rank only when there is one', () {
      RosterMember member(Object? rank) =>
          RosterMember.fromRow({'user_id': 'u1', 'account_name': 'Mira.2', 'role': 'officer', 'gw2_rank': rank});
      expect(member('Officer').gw2Rank, 'Officer');
      expect(member(null).gw2Rank, isNull);
      expect(member('').gw2Rank, isNull);
      expect(member('Officer').role, 'officer');
      expect(member('Officer').accountName, 'Mira.2');
    });
  });

  group('when a guild is read after linking', () {
    test('only an account that leads a guild asks for it', () {
      expect(
          leadsAGuild({
            'guilds': [
              {'id': 'g1', 'leader': false},
              {'id': 'g2', 'leader': true},
            ],
          }),
          isTrue);
      expect(
          leadsAGuild({
            'guilds': [
              {'id': 'g1', 'leader': false},
            ],
          }),
          isFalse);
      expect(leadsAGuild({'guilds': []}), isFalse);
      expect(leadsAGuild({'account_name': 'Leo.1'}), isFalse, reason: 'an answer without guilds');
      expect(leadsAGuild(null), isFalse);
      expect(leadsAGuild('nonsense'), isFalse);
    });
  });

  group('how the guilds were synced', () {
    test('the backend\'s answer is read, and nothing else is taken for it', () {
      final synced = parseSynced({
        'account_name': 'Leo.1',
        'synced': [
          {'id': 'g1', 'result': 'synced'},
          {'id': 'g2', 'result': 'unavailable', 'detail': 'guild:403'},
          {'id': 'g3'},
          'nonsense',
        ],
      });
      expect(synced.map((r) => r.result), ['synced', 'unavailable']);
      expect(synced[0].detail, isNull);
      expect(synced[1].detail, 'guild:403');
      expect(parseSynced(null), isEmpty);
      expect(parseSynced({'synced': 'no'}), isEmpty);
      expect(parseSynced({'account_name': 'Leo.1'}), isEmpty, reason: 'an older backend says nothing');
    });

    test('the worst result is the one told, with its reason', () {
      const s = S(AppLang.en);
      const ok = GuildSyncResult('synced', null);
      const refused = GuildSyncResult('unavailable', 'guild:403');
      expect(guildSyncMessage(s, const LinkOutcome('Leo.1', [ok])), 'Guild details updated.');
      expect(guildSyncMessage(s, const LinkOutcome('Leo.1', [ok, refused])),
          "The game would not give the guild's details (guild:403).");
      expect(guildSyncMessage(s, const LinkOutcome('Leo.1', [GuildSyncResult('failed', 'db:42501'), refused])),
          contains('db:42501'));
      expect(guildSyncMessage(s, const LinkOutcome('Leo.1', [GuildSyncResult('too_soon', null)])),
          contains('few minutes'));
      expect(guildSyncMessage(s, const LinkOutcome('Leo.1', [GuildSyncResult('synced', 'members:403')])),
          'Guild details updated. (members:403)');
    });

    test('nothing to sync and nothing to refresh are told apart', () {
      const s = S(AppLang.en);
      expect(guildSyncMessage(s, const LinkOutcome('Leo.1', [])), contains('guilds permission'));
      expect(guildSyncMessage(s, null), contains('not linked'));
    });

    test('every result has a text in every language', () {
      for (final lang in AppLang.values) {
        final s = S(lang);
        for (final r in ['synced', 'too_soon', 'unavailable', 'failed', 'none', 'skipped']) {
          expect(s.t('ginfo_result_$r', {'detail': 'X'}), isNot('ginfo_result_$r'), reason: '${lang.code} $r');
        }
        expect(s.t('ginfo_result_unavailable', {'detail': 'X'}), contains('X'), reason: lang.code);
      }
    });
  });

  test('the link and refresh buttons have their own texts in every language', () {
    for (final lang in AppLang.values) {
      final s = S(lang);
      expect(s.t('gw2_link_name', {'name': 'Leo.1'}), contains('Leo.1'), reason: lang.code);
      expect(s.t('gw2_refreshed'), isNot('gw2_refreshed'), reason: lang.code);
      expect(s.t('gw2_refresh_other'), isNot('gw2_refresh_other'), reason: lang.code);
      expect(s.t('gw2_refresh'), isNot(s.t('gw2_link')), reason: 'two different things, ${lang.code}');
    }
  });

  group('what a leader shares of the parts the game keeps to the leader', () {
    test('only an ok answer is a list, anything else is nothing', () {
      expect(
          parseSharedPart({
            'status': 'ok',
            'data': [
              {'a': 1},
              5
            ],
            'synced_at': '2026-10-01T10:00:00Z'
          }),
          [
            {'a': 1},
            5,
          ]);
      for (final none in [
        {'status': 'hidden'},
        {'status': 'empty'},
        {'status': 'unknown'},
        {'status': 'ok'},
        {'status': 'ok', 'data': 'no'},
        'ok',
        null,
        <String, dynamic>{},
      ]) {
        expect(parseSharedPart(none), isNull, reason: '$none');
      }
    });

    test('everything is shared until the leader switches a part off', () {
      final d = GuildDetails.fromRow({
        'hidden_parts': ['treasury', 'log', 'members'],
      });
      expect(d.hidden, {'treasury', 'log', 'members'});
      expect(d.shares('treasury'), isFalse);
      expect(d.shares('members'), isFalse);
      expect(d.shares('stash'), isTrue);
      expect(d.shares('storage'), isTrue);
      final none = GuildDetails.fromRow({});
      expect(none.hidden, isEmpty, reason: 'older rows have no such column');
      expect(
          ['members', 'ranks', 'teams', 'treasury', 'stash', 'log', 'upgrades', 'storage'].every(none.shares), isTrue);
      expect(GuildDetails.fromRow({'hidden_parts': 'no'}).hidden, isEmpty);
    });

    test('a part is on for the members exactly when the leader has not hidden it', () {
      // the switch shows this, on is gold, so a hidden part must read as off
      final d = GuildDetails.fromRow({
        'hidden_parts': ['stash']
      });
      expect(d.shares('stash'), isFalse);
      expect(d.shares('log'), isTrue);
      expect(const S(AppLang.en).t('gshare_on'), isNot(const S(AppLang.en).t('gshare_off')));
    });

    test('the switches and the note that a part is not shared have texts in every language', () {
      for (final lang in AppLang.values) {
        final s = S(lang);
        for (final key in [
          'gshare_title',
          'gshare_note',
          'gshare_on',
          'gshare_off',
          'guild_rank_needed',
          'treasury',
          'stash',
          'log',
          'members',
          'ranks',
          'built_upgrades',
          'hall_storage',
          'pvp_teams',
        ]) {
          expect(s.t(key), isNot(key), reason: '${lang.code} $key');
        }
      }
      expect(const S(AppLang.en).t('guild_rank_needed'), contains('turned sharing off'));
    });
  });

  group('what a place in a guild is called', () {
    test('the game\'s own rank, as the guild named it, and the app\'s word only when it is not known', () {
      const s = S(AppLang.en);
      expect(rankLabel(s, 'officer', 'Raid Lead'), 'Raid Lead');
      expect(rankLabel(s, 'member', 'Recruiter'), 'Recruiter');
      expect(rankLabel(s, 'leader', 'Guild Master'), 'Guild Master');
      expect(rankLabel(s, 'leader', null), 'Leader');
      expect(rankLabel(s, 'member', ''), 'Member');
    });

    test('a guild account keeps its rank, and none is none', () {
      expect(const GuildAccount('g', 'a', 'Leo.1', 'leader', gw2Rank: 'Boss').gw2Rank, 'Boss');
      expect(const GuildAccount('g', 'a', 'Leo.1', 'leader').gw2Rank, isNull);
      expect(nonEmpty('Raid Lead'), 'Raid Lead');
      expect(nonEmpty(''), isNull);
      expect(nonEmpty(null), isNull);
    });

    test('the note says what the ranks may do without a word for a role the game does not have', () {
      for (final lang in AppLang.values) {
        expect(S(lang).t('roster_note_game'), isNot('roster_note_game'), reason: lang.code);
      }
      expect(const S(AppLang.en).t('roster_note_game').toLowerCase(), isNot(contains('officer')));
    });
  });

  test('the roster texts about roles following the game exist in every language', () {
    for (final lang in AppLang.values) {
      final s = S(lang);
      for (final key in ['roster_manual', 'roster_follow_game', 'roster_auto']) {
        expect(s.t(key), isNot(key), reason: '${lang.code} $key');
      }
    }
  });

  group('the leader chooses before the members see', () {
    test('a guild is reviewed once the leader has confirmed, not before', () {
      expect(GuildDetails.fromRow({}).reviewed, isFalse);
      expect(GuildDetails.fromRow({'sharing_reviewed_at': null}).reviewed, isFalse);
      final d = GuildDetails.fromRow({'sharing_reviewed_at': '2026-10-01T10:00:00+00:00'});
      expect(d.reviewed, isTrue);
      expect(d.reviewedAt, DateTime.utc(2026, 10, 1, 10));
    });

    test('the texts of the choice exist in every language', () {
      for (final lang in AppLang.values) {
        final s = S(lang);
        for (final key in [
          'gshare_unreviewed',
          'gshare_confirm',
          'gshare_review_title',
          'gshare_review_intro',
          'gshare_later'
        ]) {
          expect(s.t(key), isNot(key), reason: '${lang.code} $key');
        }
      }
    });
  });

  group('the news feed', () {
    test('a phone reads the site\'s own feed, in the language of the app', () {
      expect(newsFeedRequest(AppLang.de, web: false, backend: 'https://x.supabase.co'),
          'https://www.guildwars2.com/de/feed/');
      expect(newsFeedRequest(AppLang.en, web: false, backend: ''), 'https://www.guildwars2.com/en/feed/');
    });

    test('a browser reads the backend\'s copy, which it is allowed to', () {
      expect(newsFeedRequest(AppLang.fr, web: true, backend: 'https://x.supabase.co'),
          'https://x.supabase.co/functions/v1/news-feed?lang=fr');
    });

    test('a language the site has no feed in reads English', () {
      final address = newsFeedRequest(AppLang.tr, web: true, backend: 'https://x.supabase.co');
      expect(address.endsWith('lang=en'), isTrue, reason: address);
    });

    test('with no backend a browser has nothing to ask', () {
      expect(newsFeedRequest(AppLang.en, web: true, backend: ''), isEmpty);
    });
  });

  test('what a leader shares has its texts in every language', () {
    for (final lang in AppLang.values) {
      final s = S(lang);
      expect(s.t('gshared_note'), isNot('gshared_note'), reason: lang.code);
      expect(s.t('gshared_not_linked'), isNot('gshared_not_linked'), reason: lang.code);
    }
  });

  test('the guild info texts exist in every language', () {
    for (final lang in AppLang.values) {
      final s = S(lang);
      for (final key in ['ginfo_level', 'ginfo_members', 'ginfo_pending', 'ginfo_pending_leader']) {
        expect(s.t(key), isNot(key), reason: '${lang.code} $key');
      }
      expect(s.t('ginfo_updated', {'when': 'X'}), contains('X'), reason: lang.code);
    }
  });
}
