import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/l10n/strings.dart';
import 'package:tyria_codex/screens/character_progress.dart';

void main() {
  test('the notes on the progress tab exist in every language', () {
    for (final lang in AppLang.values) {
      final s = S(lang);
      for (final key in ['progress_hero_unavailable', 'progress_training_unavailable', 'story_note']) {
        expect(s.t(key), isNot(key), reason: '${lang.code} $key');
        expect(s.t(key).length > 20, isTrue, reason: '${lang.code} $key is a sentence');
      }
    }
  });

  test('the notes say the game gives no data, not that the character has none', () {
    const s = S(AppLang.en);
    expect(s.t('progress_hero_unavailable'), contains('returns nothing'));
    expect(s.t('progress_training_unavailable'), contains('returns nothing'));
    expect(s.t('story_note'), contains('recorded'));
  });

  group('the stories of a season', () {
    final stories = <String, Map<String, dynamic>>{
      '1': {'season': 'A', 'name': 'Second', 'order': 2},
      '2': {'season': 'A', 'name': 'First', 'order': 1},
      '3': {'season': 'A', 'name': 'Not in the quest list', 'order': 3},
      '4': {'season': 'B', 'name': 'Elsewhere', 'order': 1},
    };
    final quests = <String, Map<String, dynamic>>{
      '10': {'id': 10, 'story': 1},
      '11': {'id': 11, 'story': 1},
      '12': {'id': 12, 'story': 2},
      '13': {'id': 13, 'story': 4},
    };

    test('are listed in the order of the game, with what is done of each', () {
      final rows = seasonStories('A', quests, stories, {'10', '12', '13'});
      expect(rows.map((r) => r.name), ['First', 'Second', 'Not in the quest list']);
      expect(rows.map((r) => '${r.done}/${r.total}'), ['1/1', '1/2', '0/0']);
    });

    test('a season has only its own stories', () {
      expect(seasonStories('B', quests, stories, {'13'}).map((r) => r.name), ['Elsewhere']);
      expect(seasonStories('nothing', quests, stories, {'10'}), isEmpty);
    });

    test('what the game recorded that its quest list does not have is counted apart', () {
      expect(unmatchedQuests(quests, {'10', '99', '100'}), 2);
      expect(unmatchedQuests(quests, {}), 0);
    });

    test('the note about them exists in every language and says how many', () {
      for (final lang in AppLang.values) {
        expect(S(lang).t('story_unmatched', {'n': 7}), contains('7'), reason: lang.code);
      }
    });
  });
}
