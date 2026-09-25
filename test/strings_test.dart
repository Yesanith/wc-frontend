import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/l10n/strings.dart';

/// keys are plain strings, so a typo only shows up at runtime as the raw key.
/// this reads the sources and the tables and fails the build instead
void main() {
  /// one file per language, each holding a single top level map
  Map<String, Set<String>> keysPerLanguage() {
    final key = RegExp(r"^  '([A-Za-z_0-9]+)':", multiLine: true);
    final out = <String, Set<String>>{};
    for (final lang in AppLang.values) {
      final file = File('lib/l10n/${lang.code}.dart');
      expect(file.existsSync(), isTrue, reason: 'no table for ${lang.code}');
      out[lang.code] = {
        for (final m in key.allMatches(file.readAsStringSync())) m.group(1)!,
      };
    }
    return out;
  }

  Set<String> usedKeys() {
    final used = <String>{};
    final call = RegExp(r"\.t\('([a-z_0-9]+)'");
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart') || file.path.contains('l10n')) continue;
      for (final m in call.allMatches(file.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    return used;
  }

  test('every language the app offers has a table', () {
    expect(keysPerLanguage().keys, containsAll(['en', 'de', 'es', 'fr', 'tr']));
  });

  test('every language has the same keys', () {
    final langs = keysPerLanguage();
    final english = langs['en']!;
    expect(english, isNotEmpty);
    for (final entry in langs.entries) {
      expect(entry.value.difference(english), isEmpty, reason: '${entry.key} has keys english lacks');
      expect(english.difference(entry.value), isEmpty, reason: '${entry.key} is missing keys');
    }
  });

  test('every key used in the code exists', () {
    final english = keysPerLanguage()['en']!;
    final missing = usedKeys().difference(english);
    expect(missing, isEmpty, reason: 'unknown string keys: $missing');
  });

  test('every language actually resolves a string', () {
    for (final lang in AppLang.values) {
      expect(S(lang).t('nav_settings'), isNotEmpty);
      // an unknown key falls back to the key itself rather than throwing
      expect(S(lang).t('definitely_not_a_key'), 'definitely_not_a_key');
    }
  });

  test('placeholders are filled in every language', () {
    for (final lang in AppLang.values) {
      expect(S(lang).t('n_items', {'n': 7}), contains('7'));
    }
  });
}
