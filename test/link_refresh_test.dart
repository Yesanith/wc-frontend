import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/l10n/strings.dart';
import 'package:tyria_codex/state/community.dart';
import 'package:tyria_codex/state/guild_events.dart';
import 'package:tyria_codex/state/link_refresh.dart';

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
