import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// keys are plain strings, so a typo only shows up at runtime as the raw key.
/// this reads the sources and the table and fails the build instead
void main() {
  final table = File('lib/l10n/strings.dart').readAsStringSync();

  Map<String, Set<String>> keysPerLanguage() {
    final out = <String, Set<String>>{};
    final block = RegExp(r"^  '(\w+)': \{\n(.*?)\n  \},", multiLine: true, dotAll: true);
    final key = RegExp(r"^    '([A-Za-z_0-9]+)':", multiLine: true);
    for (final m in block.allMatches(table)) {
      out[m.group(1)!] = {for (final k in key.allMatches(m.group(2)!)) k.group(1)!};
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

  test('every language has the same keys', () {
    final langs = keysPerLanguage();
    expect(langs.keys, containsAll(['en', 'de', 'fr', 'tr']));
    final english = langs['en']!;
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
}
