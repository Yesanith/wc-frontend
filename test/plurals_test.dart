import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/l10n/strings.dart';

void main() {
  test('a russian number takes the word that goes with it', () {
    const s = S(AppLang.ru);
    expect(s.t('n_gems', {'n': 1}), '1 самоцвет');
    expect(s.t('n_gems', {'n': 3}), '3 самоцвета');
    expect(s.t('n_gems', {'n': 11}), '11 самоцветов');
    expect(s.t('n_gems', {'n': 22}), '22 самоцвета');
    expect(s.t('n_gems', {'n': 25}), '25 самоцветов');
    expect(s.t('birthday_today', {'n': 21}), 'Сегодня день рождения, 21 год');
  });

  test('a text without forms is filled in as before', () {
    expect(const S(AppLang.en).t('n_gems', {'n': 1}), isNot(contains('|')));
  });
}
