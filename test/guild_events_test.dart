import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/l10n/strings.dart';
import 'package:tyria_codex/screens/guild_events_screen.dart';
import 'package:tyria_codex/state/community.dart';
import 'package:tyria_codex/state/guild_events.dart';

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
}
