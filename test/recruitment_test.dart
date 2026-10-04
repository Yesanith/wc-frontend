import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/l10n/strings.dart';
import 'package:tyria_codex/state/recruitment.dart';

const _id = '7c1d8e2a-3b4f-4a5c-8d6e-9f0a1b2c3d4e';

Map<String, dynamic> _card([Map<String, dynamic> over = const {}]) => {
      'guild_id': _id,
      'gw2_guild_id': '99999999-0000-0000-0000-00000000000a',
      'name': 'Mistwalkers',
      'tag': 'MIST',
      'headline': 'Raids on Thursdays',
      'looking_for': ['raids', 'fractals'],
      'languages': ['en', 'de'],
      'region': 'eu',
      'recruiting': true,
      'play_times': 'EU evenings',
      'updated_at': '2026-10-03T10:00:00Z',
      ...over,
    };

Map<String, dynamic> _page([Map<String, dynamic> over = const {}]) => {
      ..._card(),
      'description': 'A friendly raiding guild that plays in the evenings.',
      'requirements': 'Level 80',
      'discord_invite': 'https://discord.gg/abc123',
      'contact': 'Whisper Leo.1',
      'published_at': '2026-10-01T10:00:00Z',
      'stale': false,
      'can_edit': true,
      'is_leader': true,
      'published': true,
      'hidden': false,
      'hidden_reason': null,
      ...over,
    };

void main() {
  group('a Discord invite', () {
    test('is what the database takes: https, Discord\'s own address, and a code of letters, numbers and dashes', () {
      for (final ok in ['https://discord.gg/abc123', 'https://discord.com/invite/abc-123', 'https://discord.gg/AB']) {
        expect(isDiscordInvite(ok), isTrue, reason: ok);
      }
      for (final bad in [
        '',
        'discord.gg/abc123',
        'http://discord.gg/abc123',
        'https://example.com/abc123',
        'https://discord.gg/a',
        'https://discord.gg/a b',
        'https://discord.gg/abc123/extra',
        'https://discord.gg/${'a' * 41}',
        ' https://discord.gg/abc123',
        'https://discord.gg.evil.com/abc',
      ]) {
        expect(isDiscordInvite(bad), isFalse, reason: bad);
      }
    });
  });

  group('a guild of the list', () {
    test('is read, with its title as the game writes it', () {
      final card = RecruitCard.parse(_card())!;
      expect(card.guildId, _id);
      expect(card.title, 'Mistwalkers [MIST]');
      expect(card.headline, 'Raids on Thursdays');
      expect(card.lookingFor, ['raids', 'fractals']);
      expect(card.languages, ['en', 'de']);
      expect(card.region, RecruitRegion.eu);
      expect(card.recruiting, isTrue);
      expect(card.playTimes, 'EU evenings');
      expect(card.updatedAt, isNotNull);
    });

    test('has no brackets when it has no tag, and is recruiting unless it says it is not', () {
      final card = RecruitCard.parse(_card({'tag': '', 'recruiting': false}))!;
      expect(card.title, 'Mistwalkers');
      expect(card.recruiting, isFalse);
      expect(RecruitCard.parse({'guild_id': _id, 'name': 'X'})!.recruiting, isTrue);
    });

    test('is not read without a number or a name, and keeps what it can of the rest', () {
      expect(RecruitCard.parse(null), isNull);
      expect(RecruitCard.parse('x'), isNull);
      expect(RecruitCard.parse({'name': 'X'}), isNull);
      expect(RecruitCard.parse({'guild_id': _id}), isNull);
      final bare = RecruitCard.parse({
        'guild_id': _id,
        'name': 'X',
        'looking_for': 'raids',
        'languages': [1, 'en'],
        'region': 'asia',
        'updated_at': 'no'
      })!;
      expect(bare.lookingFor, isEmpty, reason: 'a text is not a list');
      expect(bare.languages, ['en'], reason: 'and what is in a list that is not a text is left out');
      expect(bare.region, RecruitRegion.any);
      expect(bare.updatedAt, isNull);
    });
  });

  group('the list', () {
    test('has its guilds and how many there are in all', () {
      final list = RecruitList.parse({
        'total': 45,
        'rows': [
          _card(),
          _card({'guild_id': 'b', 'name': 'B'}),
          'junk',
          {'name': 'no number'}
        ]
      });
      expect(list.rows.map((r) => r.name), ['Mistwalkers', 'B']);
      expect(list.total, 45);
    });

    test('is nothing for what is not a list', () {
      for (final raw in [null, 'x', 5, <String, dynamic>{}]) {
        final list = RecruitList.parse(raw);
        expect(list.rows, isEmpty, reason: '$raw');
        expect(list.total, 0);
      }
      expect(RecruitList.empty.rows, isEmpty);
    });
  });

  group('the page of a guild', () {
    test('is read in full, with what the player who asked may do with it', () {
      final page = RecruitPage.parse(_page())!;
      expect(page.title, 'Mistwalkers [MIST]');
      expect(page.description, startsWith('A friendly raiding guild'));
      expect(page.requirements, 'Level 80');
      expect(page.discordInvite, 'https://discord.gg/abc123');
      expect(page.contact, 'Whisper Leo.1');
      expect(page.canBeReached, isTrue);
      expect((page.canEdit, page.isLeader, page.published, page.hidden, page.stale), (true, true, true, false, false));
      expect(page.publishedAt, isNotNull);
    });

    test('is read for a visitor, who may do nothing with it', () {
      final page = RecruitPage.parse(_page({'can_edit': false, 'is_leader': false, 'hidden_reason': null}))!;
      expect((page.canEdit, page.isLeader), (false, false));
      expect(page.hiddenReason, isNull);
    });

    test('has a moderator\'s reason, and is old when the database says it is', () {
      final page = RecruitPage.parse(_page({'hidden': true, 'hidden_reason': 'Spam', 'stale': true}))!;
      expect((page.hidden, page.hiddenReason, page.stale), (true, 'Spam', true));
    });

    test('can be reached by an invite, by a name, by either, and by neither', () {
      expect(RecruitPage.parse(_page({'contact': ''}))!.canBeReached, isTrue);
      expect(RecruitPage.parse(_page({'discord_invite': null}))!.canBeReached, isTrue);
      expect(RecruitPage.parse(_page({'discord_invite': ''}))!.discordInvite, isNull,
          reason: 'an invite that is empty is none');
      expect(RecruitPage.parse(_page({'discord_invite': null, 'contact': ''}))!.canBeReached, isFalse);
    });

    test('is not read without a number or a name', () {
      expect(RecruitPage.parse(null), isNull);
      expect(RecruitPage.parse({'name': 'X'}), isNull);
      expect(RecruitPage.parse({'guild_id': _id}), isNull);
    });
  });

  group('a guild whose page the player may manage', () {
    MyRecruitGuild guild(Map<String, dynamic> over) => MyRecruitGuild.parse({
          'guild_id': _id,
          'gw2_guild_id': 'g',
          'name': 'Mistwalkers',
          'tag': 'MIST',
          'is_leader': true,
          'has_page': true,
          'published': true,
          'hidden': false,
          'stale': false,
          ...over,
        })!;

    test('has where its page is', () {
      expect(guild({'has_page': false, 'published': false}).status, RecruitStatus.none);
      expect(guild({'published': false}).status, RecruitStatus.draft);
      expect(guild({}).status, RecruitStatus.published);
      expect(guild({'stale': true}).status, RecruitStatus.stale);
      expect(guild({'hidden': true}).status, RecruitStatus.hidden);
    });

    test('is hidden whatever else it is, and a draft is not old', () {
      expect(guild({'hidden': true, 'stale': true, 'published': false}).status, RecruitStatus.hidden);
      expect(guild({'published': false, 'stale': true}).status, RecruitStatus.draft);
      expect(guild({'has_page': false, 'hidden': true}).status, RecruitStatus.none);
    });

    test('is read, with who it is the leader of', () {
      final g = guild({'is_leader': false});
      expect((g.title, g.isLeader), ('Mistwalkers [MIST]', false));
      expect(MyRecruitGuild.parse(null), isNull);
      expect(MyRecruitGuild.parse({'name': 'X'}), isNull);
    });
  });

  group('a recruiter', () {
    test('is read by the account they play', () {
      final r =
          RecruiterEntry.parse({'user_id': 'u1', 'account_name': 'Mira.2', 'granted_at': '2026-10-03T10:00:00Z'})!;
      expect((r.userId, r.accountName), ('u1', 'Mira.2'));
      expect(r.grantedAt, isNotNull);
      expect(RecruiterEntry.parse({'user_id': 'u1'})!.accountName, '?');
      expect(RecruiterEntry.parse({'account_name': 'x'}), isNull);
      expect(RecruiterEntry.parse(5), isNull);
    });
  });

  group('a page that was reported', () {
    Map<String, dynamic> row([Map<String, dynamic> over = const {}]) => {
          'guild_id': _id,
          'name': 'Mistwalkers',
          'tag': 'MIST',
          'headline': 'Raids on Thursdays',
          'reports': 3,
          'reasons': ['spam', 'rude', 'other'],
          'last_at': '2026-10-03T10:00:00Z',
          'hidden': false,
          'hidden_reason': null,
          'published': true,
          ...over,
        };

    test('is read, with how many reported it and what the last said', () {
      final r = RecruitReport.parse(row())!;
      expect(r.title, 'Mistwalkers [MIST]');
      expect(r.reports, 3);
      expect(r.reasons, ['spam', 'rude', 'other']);
      expect(r.lastAt, isNotNull);
      expect((r.hidden, r.published, r.hiddenReason), (false, true, null));
    });

    test('is read when it is hidden, with why', () {
      final r = RecruitReport.parse(row({'hidden': true, 'hidden_reason': 'Spam', 'reports': 0}))!;
      expect((r.hidden, r.hiddenReason, r.reports), (true, 'Spam', 0));
    });

    test('is not read without a number or a name, and keeps what it can of the rest', () {
      expect(RecruitReport.parse(null), isNull);
      expect(RecruitReport.parse({'name': 'X'}), isNull);
      expect(RecruitReport.parse({'guild_id': _id}), isNull);
      final bare = RecruitReport.parse({'guild_id': _id, 'name': 'X', 'reports': 'many', 'reasons': 'no'})!;
      expect(bare.reports, 0);
      expect(bare.reasons, isEmpty);
      expect(bare.title, 'X');
    });
  });

  group('a page being edited', () {
    test('is what the page was, and is sent whole', () {
      final draft = RecruitDraft.fromPage(RecruitPage.parse(_page())!);
      expect(draft.toJson(), {
        'headline': 'Raids on Thursdays',
        'description': 'A friendly raiding guild that plays in the evenings.',
        'requirements': 'Level 80',
        'play_times': 'EU evenings',
        'contact': 'Whisper Leo.1',
        'discord_invite': 'https://discord.gg/abc123',
        'looking_for': ['fractals', 'raids'],
        'languages': ['de', 'en'],
        'region': 'eu',
        'recruiting': true,
      });
    });

    test('is sent trimmed, with an invite that is empty as none, and its lists in order', () {
      final json = const RecruitDraft(
          headline: '  Hi  ',
          discordInvite: '   ',
          lookingFor: {'raids', 'casual', 'fractals'},
          languages: {'tr', 'en'}).toJson();
      expect(json['headline'], 'Hi');
      expect(json['discord_invite'], isNull);
      expect(json['looking_for'], ['casual', 'fractals', 'raids']);
      expect(json['languages'], ['en', 'tr']);
      expect(json['region'], 'any');
    });

    test('is changed a field at a time, and the rest is as it was', () {
      const a = RecruitDraft(headline: 'A', contact: 'c');
      final b = a.copyWith(headline: 'B', region: RecruitRegion.na, recruiting: false);
      expect((b.headline, b.contact, b.region, b.recruiting), ('B', 'c', RecruitRegion.na, false));
      expect(a.headline, 'A', reason: 'and the first is not touched');
    });

    test('has nothing wrong with it when it is as long as it may be, and each field that is too long when it is not',
        () {
      expect(const RecruitDraft().problems(), isEmpty);
      expect(
          RecruitDraft(
                  headline: 'x' * 80,
                  description: 'y' * 2000,
                  requirements: 'z' * 500,
                  playTimes: 'p' * 120,
                  contact: 'c' * 120)
              .problems(),
          isEmpty);
      expect(RecruitDraft(headline: 'x' * 81).problems(), [RecruitField.headline]);
      expect(RecruitDraft(description: 'x' * 2001).problems(), [RecruitField.description]);
      expect(RecruitDraft(requirements: 'x' * 501).problems(), [RecruitField.requirements]);
      expect(RecruitDraft(playTimes: 'x' * 121).problems(), [RecruitField.playTimes]);
      expect(RecruitDraft(contact: 'x' * 121).problems(), [RecruitField.contact]);
      expect(RecruitDraft(headline: '${' ' * 50}x${' ' * 50}').problems(), isEmpty,
          reason: 'spaces round a text are not counted: the database trims it');
    });

    test('has an invite that is not an invite', () {
      expect(const RecruitDraft(discordInvite: 'https://example.com/x').problems(), [RecruitField.discordInvite]);
      expect(const RecruitDraft(discordInvite: '  https://discord.gg/abc123  ').problems(), isEmpty);
    });

    test(
        'chooses five tags at the most, between what it looks for and its languages, which are the tags of its post in the forum',
        () {
      expect(recruitTagsMax, 5);
      expect(RecruitDraft(lookingFor: recruitTags.take(5).toSet()).problems(), isEmpty,
          reason: 'five things looked for');
      expect(RecruitDraft(languages: recruitLanguages.take(5).toSet()).problems(), isEmpty, reason: 'five languages');
      expect(
          RecruitDraft(lookingFor: recruitTags.take(3).toSet(), languages: recruitLanguages.take(2).toSet()).problems(),
          isEmpty,
          reason: 'three and two');
      expect(RecruitDraft(lookingFor: recruitTags.take(6).toSet()).problems(), [RecruitField.tags]);
      expect(RecruitDraft(languages: recruitLanguages.take(6).toSet()).problems(), [RecruitField.tags]);
      expect(
          RecruitDraft(lookingFor: recruitTags.take(3).toSet(), languages: recruitLanguages.take(3).toSet()).problems(),
          [RecruitField.tags],
          reason: 'three and three');
      expect(RecruitDraft(lookingFor: recruitTags.take(4).toSet(), languages: {'en'}).problems(), isEmpty,
          reason: 'four and one');
    });

    test(
        'plays in the languages that the forum has a tag for, and a language of another kind is a problem to be taken off',
        () {
      expect(recruitLanguages, ['en', 'de', 'es', 'fr', 'tr', 'pt', 'ru']);
      expect(RecruitDraft(languages: {'ja'}).problems(), [RecruitField.languages], reason: 'Japanese is no tag');
      expect(RecruitDraft(languages: {'zh'}).problems(), [RecruitField.languages]);
      expect(RecruitDraft(languages: {'it'}).problems(), [RecruitField.languages]);
      expect(RecruitDraft(languages: {'en', 'ja'}).problems(), [RecruitField.languages]);
      expect(RecruitDraft(lookingFor: recruitTags.take(5).toSet(), languages: {'ja'}).problems(),
          [RecruitField.tags, RecruitField.languages],
          reason: 'both');
    });

    test(
        'lacks what is needed to be shown to everybody: a headline, a description of twenty characters and a way to be reached',
        () {
      expect(const RecruitDraft().missingToPublish(),
          [RecruitField.headline, RecruitField.description, RecruitField.contact]);
      const whole = RecruitDraft(headline: 'H', description: 'twenty characters!!!', contact: 'Whisper me');
      expect(whole.missingToPublish(), isEmpty);
      expect(whole.copyWith(description: 'nineteen characters').missingToPublish(), [RecruitField.description]);
      expect(whole.copyWith(headline: '   ').missingToPublish(), [RecruitField.headline]);
      expect(whole.copyWith(contact: '', discordInvite: 'https://discord.gg/abc123').missingToPublish(), isEmpty,
          reason: 'an invite is a way');
      expect(whole.copyWith(contact: '  ').missingToPublish(), [RecruitField.contact]);
      expect(whole.copyWith(description: ' ${'x' * 19} ').missingToPublish(), [RecruitField.description],
          reason: 'trimmed before it is counted');
    });
  });

  group('what the player is told of a failure', () {
    test('is a word for each hint the database gives', () {
      const expected = {
        'not_allowed': 'rec_err_not_allowed',
        'not_signed_in': 'rec_err_signin',
        'incomplete': 'rec_publish_needs',
        'hidden': 'rec_err_hidden',
        'invalid_field': 'rec_err_invalid',
        'invalid_filter': 'rec_err_invalid',
        'not_member': 'rec_err_not_member',
        'own_role': 'rec_err_own_role',
        'is_leader': 'rec_err_own_role',
        'no_page': 'rec_err_no_page',
        'not_found': 'rec_not_found',
        'too_many': 'rec_err_too_many',
        'own_guild': 'rec_err_own_guild',
        'unavailable': 'rec_unavailable',
      };
      expected.forEach((hint, key) => expect(recruitErrorKey(RecruitFailure(hint)), key, reason: hint));
      expect(recruitErrorKey(const RecruitFailure('something new')), 'rec_err_generic');
      expect(recruitErrorKey('not a failure'), 'rec_err_generic');
      expect(const RecruitFailure('x').toString(), contains('x'));
    });

    test('is a word in every language, for each of them', () {
      final keys = {
        'rec_err_not_allowed', 'rec_err_signin', 'rec_publish_needs', 'rec_err_hidden', 'rec_err_invalid',
        'rec_err_not_member', 'rec_err_own_role',
        'rec_err_no_page', 'rec_not_found', 'rec_err_too_many', 'rec_err_own_guild', 'rec_unavailable',
        'rec_err_generic', //
      };
      for (final lang in AppLang.values) {
        final s = S(lang);
        for (final key in keys) {
          expect(s.t(key), isNot(key), reason: '$key in ${lang.code}');
        }
      }
    });
  });

  group('the words of a page', () {
    test('are one for each thing a guild may look for, in every language', () {
      for (final lang in AppLang.values) {
        final s = S(lang);
        final names = [for (final tag in recruitTags) recruitTagLabel(s, tag)];
        expect(names.toSet().length, recruitTags.length,
            reason: 'each of them is called something of its own in ${lang.code}');
        for (final (i, name) in names.indexed) {
          expect(name, isNot(recruitTags[i]), reason: '${recruitTags[i]} has a word in ${lang.code}');
        }
      }
      expect(recruitTagLabel(S(AppLang.en), 'something new'), 'something new',
          reason: 'what is not known is shown as it is');
    });

    test('are the name of a language as it is written, or its code in capitals', () {
      expect(recruitLanguageLabel('de'), 'Deutsch');
      expect(recruitLanguageLabel('ja'), '日本語');
      expect(recruitLanguageLabel('it'), 'IT');
      for (final code in recruitLanguages) {
        expect(recruitLanguageLabel(code), isNot(code.toUpperCase()), reason: code);
      }
    });

    test('are a region in the language of the app', () {
      final s = S(AppLang.en);
      expect(recruitRegionLabel(s, RecruitRegion.eu), 'Europe');
      expect(recruitRegionLabel(s, RecruitRegion.na), 'North America');
      expect(recruitRegionLabel(s, RecruitRegion.any), 'Any region');
      expect(RecruitRegion.parse('na'), RecruitRegion.na);
      expect(RecruitRegion.parse('asia'), RecruitRegion.any);
      expect(RecruitRegion.parse(null), RecruitRegion.any);
      expect(RecruitRegion.eu.code, 'eu');
    });
  });
}
