import 'de.dart';
import 'en.dart';
import 'es.dart';
import 'fr.dart';
import 'tr.dart';

/// app languages. the gw2 api has no turkish data so tr falls back to
/// english for item names etc, and uses the english wiki
enum AppLang {
  en('en', 'English', 'en', 'https://wiki.guildwars2.com'),
  de('de', 'Deutsch', 'de', 'https://wiki-de.guildwars2.com'),
  es('es', 'Español', 'es', 'https://wiki-es.guildwars2.com'),
  fr('fr', 'Français', 'fr', 'https://wiki-fr.guildwars2.com'),
  tr('tr', 'Türkçe', 'en', 'https://wiki.guildwars2.com');

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
    args?.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
    return text;
  }
}

/// one file per language, so a table of a few hundred keys stays readable
const _strings = <String, Map<String, String>>{
  'en': enStrings,
  'de': deStrings,
  'es': esStrings,
  'fr': frStrings,
  'tr': trStrings,
};
