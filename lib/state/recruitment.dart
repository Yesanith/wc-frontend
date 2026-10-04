import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/strings.dart';
import 'community.dart';

part 'recruitment/backend.dart';
part 'recruitment/models.dart';

/// what a guild may say it is looking for, as the database knows them. the app has words for each (rec_tag_<code>)
const recruitTags = [
  'raids', 'fractals', 'strikes', 'dungeons', 'open_world', 'achievements', 'wvw', 'pvp', 'farming', 'casual', 'social',
  'newcomers', 'roleplay', //
];

/// what a thing a guild looks for is called, in the language of the app. most have a word already (the activities of events, the tags); the others have their own
String recruitTagLabel(S s, String tag) => s.t(switch (tag) {
      'raids' => 'raids',
      'dungeons' => 'dungeons',
      'fractals' => 'cat_fractals',
      'wvw' => 'activity_wvw',
      'pvp' => 'activity_pvp',
      'achievements' => 'achievements',
      'casual' => 'oe_tag_casual',
      'newcomers' => 'oe_tag_new_players',
      'strikes' => 'rec_tag_strikes',
      'open_world' => 'rec_tag_open_world',
      'farming' => 'rec_tag_farming',
      'social' => 'rec_tag_social',
      'roleplay' => 'rec_tag_roleplay',
      _ => tag,
    });

/// a language by the name it is written in (Deutsch), or by its code in capitals for one the app has no name for
String recruitLanguageLabel(String code) {
  for (final l in AppLang.values) {
    if (l.code == code) return l.nativeName;
  }
  return code.toUpperCase();
}

/// a region in the language of the app
String recruitRegionLabel(S s, RecruitRegion region) => s.t(switch (region) {
      RecruitRegion.eu => 'oe_region_eu',
      RecruitRegion.na => 'oe_region_na',
      RecruitRegion.any => 'rec_region_any',
    });

/// the languages a guild may say it plays in: the seven that the forum of the official server has a tag for, which is what the database takes. a page that chose another before shows it as it is, to be taken off
const recruitLanguages = ['en', 'de', 'es', 'fr', 'tr', 'pt', 'ru'];

/// how much a page may hold, as the database keeps it
const recruitHeadlineMax = 80;
const recruitDescriptionMax = 2000;
const recruitRequirementsMax = 500;
const recruitPlayTimesMax = 120;
const recruitContactMax = 120;

/// what a page looks for and its languages are the tags of its post in the forum, which carries five at the most: five between the two
const recruitTagsMax = 5;
const recruitDescriptionMin = 20;

/// how many guilds a page of the list holds
const recruitPageSize = 30;

/// the address of a Discord invite that a page may have: the same as the database's
final _invite = RegExp(r'^https://discord\.(gg|com/invite)/[A-Za-z0-9-]{2,40}$');

bool isDiscordInvite(String text) => _invite.hasMatch(text);
