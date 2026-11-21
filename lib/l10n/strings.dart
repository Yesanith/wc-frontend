import 'de.dart' deferred as de;
import 'en.dart';
import 'es.dart' deferred as es;
import 'fr.dart' deferred as fr;
import 'ja.dart' deferred as ja;
import 'pt.dart' deferred as pt;
import 'ru.dart' deferred as ru;
import 'tr.dart' deferred as tr;
import 'zh.dart' deferred as zh;

/// app languages. the gw2 api has no turkish, portuguese, russian or
/// japanese data, those fall back to english item names and the english wiki
enum AppLang {
  en('en', 'English', 'en', 'https://wiki.guildwars2.com'),
  de('de', 'Deutsch', 'de', 'https://wiki-de.guildwars2.com'),
  es('es', 'Español', 'es', 'https://wiki-es.guildwars2.com'),
  fr('fr', 'Français', 'fr', 'https://wiki-fr.guildwars2.com'),
  tr('tr', 'Türkçe', 'en', 'https://wiki.guildwars2.com'),
  pt('pt', 'Português', 'en', 'https://wiki.guildwars2.com'),
  ru('ru', 'Русский', 'en', 'https://wiki.guildwars2.com'),
  ja('ja', '日本語', 'en', 'https://wiki.guildwars2.com'),
  // the api translates game data into chinese, the wiki has no chinese edition
  zh('zh', '中文', 'zh', 'https://wiki.guildwars2.com');

  const AppLang(this.code, this.nativeName, this.apiLang, this.wikiBase);

  final String code;
  final String nativeName;
  final String apiLang;
  final String wikiBase;

  static AppLang fromCode(String code) => AppLang.values.firstWhere((l) => l.code == code, orElse: () => AppLang.en);
}

/// ui strings. `{name}` placeholders get filled from [args]
class S {
  const S(this.lang);

  final AppLang lang;

  String t(String key, [Map<String, Object?>? args]) {
    var text = _strings[lang.code]?[key] ?? _strings['en']![key] ?? key;
    if (args != null && text.contains('|')) text = _plurals(text, args);
    args?.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
    return text;
  }

  /// `{n|one|few|many}` picks the word that goes with the number [n]: three forms follow the Slavic rule (1, 21 · 2–4, 22–24 ·
  /// the rest), two are one and the rest
  static String _plurals(String text, Map<String, Object?> args) => text.replaceAllMapped(_pluralPattern, (m) {
        final v = args[m[1]];
        final n = v is num ? v.abs().floor() : int.tryParse('$v');
        final forms = m[2]!.split('|');
        if (n == null) return forms.last;
        if (forms.length == 2) return n == 1 ? forms[0] : forms[1];
        final ten = n % 10, hundred = n % 100;
        if (ten == 1 && hundred != 11) return forms[0];
        if (ten >= 2 && ten <= 4 && (hundred < 12 || hundred > 14)) return forms[1];
        return forms[2];
      });

  static final _pluralPattern = RegExp(r'\{(\w+)\|([^{}]*)\}');
}

/// one file per language, so a table of a few hundred keys stays readable. english is always there, as the words every other
/// language falls back to; the others are loaded when they are chosen: in a browser each is a part of its own, so the page does
/// not download the words of nine languages to show one
final _strings = <String, Map<String, String>>{'en': enStrings};

/// whether the words of [lang] are there to be shown
bool languageLoaded(AppLang lang) => _strings.containsKey(lang.code);

/// loads the words of [lang], once. a language that cannot be loaded (the network dropped) is shown in english
Future<void> loadLanguage(AppLang lang) async {
  if (languageLoaded(lang)) return;
  try {
    switch (lang) {
      case AppLang.en:
        return;
      case AppLang.de:
        await de.loadLibrary();
        _strings['de'] = de.deStrings;
      case AppLang.es:
        await es.loadLibrary();
        _strings['es'] = es.esStrings;
      case AppLang.fr:
        await fr.loadLibrary();
        _strings['fr'] = fr.frStrings;
      case AppLang.tr:
        await tr.loadLibrary();
        _strings['tr'] = tr.trStrings;
      case AppLang.pt:
        await pt.loadLibrary();
        _strings['pt'] = pt.ptStrings;
      case AppLang.ru:
        await ru.loadLibrary();
        _strings['ru'] = ru.ruStrings;
      case AppLang.ja:
        await ja.loadLibrary();
        _strings['ja'] = ja.jaStrings;
      case AppLang.zh:
        await zh.loadLibrary();
        _strings['zh'] = zh.zhStrings;
    }
  } catch (_) {
    // the english words stand in
  }
}

/// every language at once, for the tests
Future<void> loadAllLanguages() => Future.wait(AppLang.values.map(loadLanguage));
