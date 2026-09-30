import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/l10n/strings.dart';

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
}
