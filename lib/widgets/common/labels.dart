import 'dart:async';

import '../../api/gw2_api.dart';
import '../../l10n/strings.dart';

/// crafting disciplines come from the api in english, translate the known ones
const _disciplines = {
  'Armorsmith',
  'Artificer',
  'Chef',
  'Huntsman',
  'Jeweler',
  'Leatherworker',
  'Scribe',
  'Tailor',
  'Weaponsmith',
  'Homesteader',
};

String disciplineLabel(S s, String discipline) =>
    _disciplines.contains(discipline) ? s.t('disc_${discipline.toLowerCase()}') : discipline;

/// a term the api gives as an english name or enum, in the language of the app when there are words for it, otherwise
/// as the api spells it with spaces between its words (GuildHallExpedition: Guild Hall Expedition)
String _term(S s, String prefix, String raw) {
  final key = '$prefix${raw.toLowerCase()}';
  final text = s.t(key);
  return text == key
      ? raw.replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (m) => ' ${m[1]}').replaceAll('_', ' ')
      : text;
}

/// an item's rarity: Exotic, Exotisch, Egzotik
String rarityLabel(S s, String rarity) => _term(s, 'rarity_', rarity);

/// a weapon by its type as items and professions name it (Greatsword, LongBow, Harpoon)
String weaponLabel(S s, String type) {
  final key = switch (type) { 'LongBow' => 'Longbow', 'ShortBow' => 'Shortbow', 'Harpoon' => 'Spear', _ => type };
  return _term(s, 'wpn_', key);
}

/// what happened in a guild, by the type of an entry of its log (joined, rank_change, treasury...)
String guildLogLabel(S s, String type) {
  final text = _term(s, 'glog_', type);
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// the kind of a guild upgrade (GuildHall, BankBag, Decoration...)
String guildUpgradeTypeLabel(S s, String type) => _term(s, 'gupg_', type);

/// a failure in plain words. the api's own text stays as a small detail
/// for anything that is not simply "no connection"
String friendlyError(S s, Object? error) {
  if (error is Gw2ApiException) {
    return switch (error.kind) {
      ApiErrorKind.offline => s.t('err_offline'),
      ApiErrorKind.timeout => s.t('err_timeout'),
      ApiErrorKind.unauthorized => s.t('err_unauthorized'),
      ApiErrorKind.notFound => s.t('err_not_found'),
      ApiErrorKind.rateLimited => s.t('err_rate_limited'),
      ApiErrorKind.server => s.t('err_server'),
      ApiErrorKind.noKey => s.t('err_no_key'),
      ApiErrorKind.other => s.t('err_generic'),
    };
  }
  if (error is TimeoutException) return s.t('err_timeout');
  return s.t('err_generic');
}
