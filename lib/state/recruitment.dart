import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/strings.dart';
import 'community.dart';

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

/// the languages a guild is offered to say it plays in. the database takes any two lowercase letters, and what it has of others is shown as it is
const recruitLanguages = ['en', 'de', 'es', 'fr', 'tr', 'pt', 'ru', 'ja', 'zh'];

/// how much a page may hold, as the database keeps it
const recruitHeadlineMax = 80;
const recruitDescriptionMax = 2000;
const recruitRequirementsMax = 500;
const recruitPlayTimesMax = 120;
const recruitContactMax = 120;
const recruitTagsMax = 8;
const recruitLanguagesMax = 5;
const recruitDescriptionMin = 20;

/// how many guilds a page of the list holds
const recruitPageSize = 30;

/// the address of a Discord invite that a page may have: the same as the database's
final _invite = RegExp(r'^https://discord\.(gg|com/invite)/[A-Za-z0-9-]{2,40}$');

bool isDiscordInvite(String text) => _invite.hasMatch(text);

enum RecruitRegion {
  any,
  eu,
  na;

  String get code => name;

  static RecruitRegion parse(Object? value) =>
      values.firstWhere((r) => r.name == value, orElse: () => RecruitRegion.any);
}

List<String> _strings(Object? v) => [
      if (v is List)
        for (final e in v)
          if (e is String) e,
    ];

DateTime? _time(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// one guild of the list
class RecruitCard {
  const RecruitCard({
    required this.guildId,
    required this.gw2GuildId,
    required this.name,
    required this.tag,
    required this.headline,
    required this.lookingFor,
    required this.languages,
    required this.region,
    required this.recruiting,
    required this.playTimes,
    this.updatedAt,
  });

  final String guildId;

  /// the guild's number in the game, which the emblem is read with
  final String gw2GuildId;
  final String name;
  final String tag;
  final String headline;
  final List<String> lookingFor;
  final List<String> languages;
  final RecruitRegion region;
  final bool recruiting;
  final String playTimes;
  final DateTime? updatedAt;

  /// the name with its tag as the game writes it: Mistwalkers [MIST]
  String get title => tag.isEmpty ? name : '$name [$tag]';

  static RecruitCard? parse(Object? raw) {
    if (raw is! Map || raw['guild_id'] is! String || raw['name'] is! String) return null;
    return RecruitCard(
      guildId: raw['guild_id'] as String,
      gw2GuildId: '${raw['gw2_guild_id'] ?? ''}',
      name: raw['name'] as String,
      tag: '${raw['tag'] ?? ''}',
      headline: '${raw['headline'] ?? ''}',
      lookingFor: _strings(raw['looking_for']),
      languages: _strings(raw['languages']),
      region: RecruitRegion.parse(raw['region']),
      recruiting: raw['recruiting'] != false,
      playTimes: '${raw['play_times'] ?? ''}',
      updatedAt: _time(raw['updated_at']),
    );
  }
}

/// a page of the list, and how many there are in all
class RecruitList {
  const RecruitList({required this.rows, required this.total});

  final List<RecruitCard> rows;
  final int total;

  static const empty = RecruitList(rows: [], total: 0);

  static RecruitList parse(Object? raw) {
    final map = raw is Map ? raw : const {};
    final total = map['total'];
    return RecruitList(
      rows: [
        for (final r in (map['rows'] as List? ?? const []))
          if (RecruitCard.parse(r) case final card?) card,
      ],
      total: total is num ? total.toInt() : 0,
    );
  }
}

/// the page of a guild: what it says of itself and how to reach it, and what the player who asks may do with it
class RecruitPage {
  const RecruitPage({
    required this.guildId,
    required this.gw2GuildId,
    required this.name,
    required this.tag,
    this.headline = '',
    this.description = '',
    this.requirements = '',
    this.playTimes = '',
    this.lookingFor = const [],
    this.languages = const [],
    this.region = RecruitRegion.any,
    this.recruiting = true,
    this.discordInvite,
    this.contact = '',
    this.updatedAt,
    this.publishedAt,
    this.stale = false,
    this.canEdit = false,
    this.isLeader = false,
    this.published = false,
    this.hidden = false,
    this.hiddenReason,
  });

  final String guildId;
  final String gw2GuildId;
  final String name;
  final String tag;
  final String headline;
  final String description;
  final String requirements;
  final String playTimes;
  final List<String> lookingFor;
  final List<String> languages;
  final RecruitRegion region;
  final bool recruiting;
  final String? discordInvite;
  final String contact;
  final DateTime? updatedAt;
  final DateTime? publishedAt;

  /// not touched for sixty days: it is not in the list, and is at its link
  final bool stale;

  /// the player who asked may edit it
  final bool canEdit;
  final bool isLeader;
  final bool published;

  /// a moderator hid it: only those who manage it see it
  final bool hidden;
  final String? hiddenReason;

  String get title => tag.isEmpty ? name : '$name [$tag]';

  /// there is a way to reach the guild
  bool get canBeReached => discordInvite != null || contact.isNotEmpty;

  static RecruitPage? parse(Object? raw) {
    if (raw is! Map || raw['guild_id'] is! String || raw['name'] is! String) return null;
    return RecruitPage(
      guildId: raw['guild_id'] as String,
      gw2GuildId: '${raw['gw2_guild_id'] ?? ''}',
      name: raw['name'] as String,
      tag: '${raw['tag'] ?? ''}',
      headline: '${raw['headline'] ?? ''}',
      description: '${raw['description'] ?? ''}',
      requirements: '${raw['requirements'] ?? ''}',
      playTimes: '${raw['play_times'] ?? ''}',
      lookingFor: _strings(raw['looking_for']),
      languages: _strings(raw['languages']),
      region: RecruitRegion.parse(raw['region']),
      recruiting: raw['recruiting'] != false,
      discordInvite: raw['discord_invite'] is String && (raw['discord_invite'] as String).isNotEmpty
          ? raw['discord_invite'] as String
          : null,
      contact: '${raw['contact'] ?? ''}',
      updatedAt: _time(raw['updated_at']),
      publishedAt: _time(raw['published_at']),
      stale: raw['stale'] == true,
      canEdit: raw['can_edit'] == true,
      isLeader: raw['is_leader'] == true,
      published: raw['published'] == true,
      hidden: raw['hidden'] == true,
      hiddenReason: raw['hidden_reason'] is String ? raw['hidden_reason'] as String : null,
    );
  }
}

/// where the page of a guild that the player may manage is
enum RecruitStatus { none, draft, published, stale, hidden }

class MyRecruitGuild {
  const MyRecruitGuild({
    required this.guildId,
    required this.gw2GuildId,
    required this.name,
    required this.tag,
    required this.isLeader,
    required this.hasPage,
    required this.published,
    required this.hidden,
    required this.stale,
  });

  final String guildId;
  final String gw2GuildId;
  final String name;
  final String tag;
  final bool isLeader;
  final bool hasPage;
  final bool published;
  final bool hidden;
  final bool stale;

  String get title => tag.isEmpty ? name : '$name [$tag]';

  RecruitStatus get status {
    if (!hasPage) return RecruitStatus.none;
    if (hidden) return RecruitStatus.hidden;
    if (!published) return RecruitStatus.draft;
    return stale ? RecruitStatus.stale : RecruitStatus.published;
  }

  static MyRecruitGuild? parse(Object? raw) {
    if (raw is! Map || raw['guild_id'] is! String || raw['name'] is! String) return null;
    return MyRecruitGuild(
      guildId: raw['guild_id'] as String,
      gw2GuildId: '${raw['gw2_guild_id'] ?? ''}',
      name: raw['name'] as String,
      tag: '${raw['tag'] ?? ''}',
      isLeader: raw['is_leader'] == true,
      hasPage: raw['has_page'] == true,
      published: raw['published'] == true,
      hidden: raw['hidden'] == true,
      stale: raw['stale'] == true,
    );
  }
}

/// a member the leader allowed to edit the page
class RecruiterEntry {
  const RecruiterEntry({required this.userId, required this.accountName, this.grantedAt});

  final String userId;
  final String accountName;
  final DateTime? grantedAt;

  static RecruiterEntry? parse(Object? raw) {
    if (raw is! Map || raw['user_id'] is! String) return null;
    return RecruiterEntry(
        userId: raw['user_id'] as String,
        accountName: '${raw['account_name'] ?? '?'}',
        grantedAt: _time(raw['granted_at']));
  }
}

/// what a page is being edited into
class RecruitDraft {
  const RecruitDraft({
    this.headline = '',
    this.description = '',
    this.requirements = '',
    this.playTimes = '',
    this.contact = '',
    this.discordInvite = '',
    this.lookingFor = const {},
    this.languages = const {},
    this.region = RecruitRegion.any,
    this.recruiting = true,
  });

  factory RecruitDraft.fromPage(RecruitPage p) => RecruitDraft(
        headline: p.headline,
        description: p.description,
        requirements: p.requirements,
        playTimes: p.playTimes,
        contact: p.contact,
        discordInvite: p.discordInvite ?? '',
        lookingFor: p.lookingFor.toSet(),
        languages: p.languages.toSet(),
        region: p.region,
        recruiting: p.recruiting,
      );

  final String headline;
  final String description;
  final String requirements;
  final String playTimes;
  final String contact;
  final String discordInvite;
  final Set<String> lookingFor;
  final Set<String> languages;
  final RecruitRegion region;
  final bool recruiting;

  RecruitDraft copyWith({
    String? headline,
    String? description,
    String? requirements,
    String? playTimes,
    String? contact,
    String? discordInvite,
    Set<String>? lookingFor,
    Set<String>? languages,
    RecruitRegion? region,
    bool? recruiting,
  }) =>
      RecruitDraft(
        headline: headline ?? this.headline,
        description: description ?? this.description,
        requirements: requirements ?? this.requirements,
        playTimes: playTimes ?? this.playTimes,
        contact: contact ?? this.contact,
        discordInvite: discordInvite ?? this.discordInvite,
        lookingFor: lookingFor ?? this.lookingFor,
        languages: languages ?? this.languages,
        region: region ?? this.region,
        recruiting: recruiting ?? this.recruiting,
      );

  /// what is sent: every field, so that the page is what is on the screen
  Map<String, dynamic> toJson() => {
        'headline': headline.trim(),
        'description': description.trim(),
        'requirements': requirements.trim(),
        'play_times': playTimes.trim(),
        'contact': contact.trim(),
        'discord_invite': discordInvite.trim().isEmpty ? null : discordInvite.trim(),
        'looking_for': lookingFor.toList()..sort(),
        'languages': languages.toList()..sort(),
        'region': region.code,
        'recruiting': recruiting,
      };

  /// what is wrong with the page as it is, before it is sent: a field that is too long or is not what it should be. the database checks the same
  List<RecruitField> problems() => [
        if (headline.trim().length > recruitHeadlineMax) RecruitField.headline,
        if (description.trim().length > recruitDescriptionMax) RecruitField.description,
        if (requirements.trim().length > recruitRequirementsMax) RecruitField.requirements,
        if (playTimes.trim().length > recruitPlayTimesMax) RecruitField.playTimes,
        if (contact.trim().length > recruitContactMax) RecruitField.contact,
        if (discordInvite.trim().isNotEmpty && !isDiscordInvite(discordInvite.trim())) RecruitField.discordInvite,
        if (lookingFor.length > recruitTagsMax) RecruitField.lookingFor,
        if (languages.length > recruitLanguagesMax) RecruitField.languages,
      ];

  /// what it takes to be shown to everybody: a headline, a description and a way to be reached
  List<RecruitField> missingToPublish() => [
        if (headline.trim().isEmpty) RecruitField.headline,
        if (description.trim().length < recruitDescriptionMin) RecruitField.description,
        if (discordInvite.trim().isEmpty && contact.trim().isEmpty) RecruitField.contact,
      ];
}

/// the fields of a page, for saying which one is not right
enum RecruitField { headline, description, requirements, playTimes, contact, discordInvite, lookingFor, languages }

/// why the database refused, as the hint it gave
class RecruitFailure implements Exception {
  const RecruitFailure(this.code);

  final String code;

  @override
  String toString() => 'RecruitFailure($code)';
}

/// the text to tell the player about a failure: the key of a string
String recruitErrorKey(Object e) {
  const keys = {
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
  return e is RecruitFailure ? (keys[e.code] ?? 'rec_err_generic') : 'rec_err_generic';
}

/// what the list is asked for: a language, a region, one thing looked for, a text, only the guilds that are recruiting, and how many are skipped
typedef RecruitFilter = ({
  String? language,
  RecruitRegion? region,
  String? lookingFor,
  String search,
  bool openOnly,
  int offset
});

const noRecruitFilter = (language: null, region: null, lookingFor: null, search: '', openOnly: false, offset: 0);

/// what the app asks of the database for recruitment. a pretend one in a test
abstract interface class RecruitBackend {
  Future<RecruitList> list(RecruitFilter filter);

  /// null when there is no page for whoever asks
  Future<RecruitPage?> page(String guildId);

  /// the guilds the player may manage the page of
  Future<List<MyRecruitGuild>> mine();
  Future<RecruitPage?> save(String guildId, RecruitDraft draft);
  Future<RecruitPage?> setPublished(String guildId, bool published);
  Future<void> touch(String guildId);
  Future<void> delete(String guildId);
  Future<List<RecruiterEntry>> recruiters(String guildId);
  Future<void> grant(String guildId, String userId);
  Future<void> revoke(String guildId, String userId);
  Future<void> report(String guildId, String reason);
}

class SupabaseRecruitBackend implements RecruitBackend {
  const SupabaseRecruitBackend();

  SupabaseClient get _client => Supabase.instance.client;

  /// a call, with a refusal of the database as a failure that has the hint it gave
  Future<Object?> _rpc(String fn, [Map<String, dynamic> params = const {}]) async {
    if (!communityReady) throw const RecruitFailure('unavailable');
    try {
      return await _client.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      throw RecruitFailure(e.hint ?? e.code ?? 'error');
    }
  }

  @override
  Future<RecruitList> list(RecruitFilter f) async => RecruitList.parse(await _rpc('recruiting_guilds', {
        'p_language': f.language,
        'p_region': f.region?.code,
        'p_looking_for': f.lookingFor,
        'p_search': f.search.trim().isEmpty ? null : f.search.trim(),
        'p_open_only': f.openOnly,
        'p_limit': recruitPageSize,
        'p_offset': f.offset,
      }));

  @override
  Future<RecruitPage?> page(String guildId) async =>
      RecruitPage.parse(await _rpc('recruitment_page', {'p_guild': guildId}));

  @override
  Future<List<MyRecruitGuild>> mine() async {
    final raw = await _rpc('my_recruitment_guilds');
    return [
      if (raw is List)
        for (final r in raw)
          if (MyRecruitGuild.parse(r) case final g?) g,
    ];
  }

  @override
  Future<RecruitPage?> save(String guildId, RecruitDraft draft) async =>
      RecruitPage.parse(await _rpc('save_recruitment', {'p_guild': guildId, 'p_data': draft.toJson()}));

  @override
  Future<RecruitPage?> setPublished(String guildId, bool published) async =>
      RecruitPage.parse(await _rpc('set_recruitment_published', {'p_guild': guildId, 'p_published': published}));

  @override
  Future<void> touch(String guildId) async {
    await _rpc('touch_recruitment', {'p_guild': guildId});
  }

  @override
  Future<void> delete(String guildId) async {
    await _rpc('delete_recruitment', {'p_guild': guildId});
  }

  @override
  Future<List<RecruiterEntry>> recruiters(String guildId) async {
    final raw = await _rpc('guild_recruiters', {'p_guild': guildId});
    return [
      if (raw is List)
        for (final r in raw)
          if (RecruiterEntry.parse(r) case final e?) e,
    ];
  }

  @override
  Future<void> grant(String guildId, String userId) async {
    await _rpc('grant_recruiter', {'p_guild': guildId, 'p_user': userId});
  }

  @override
  Future<void> revoke(String guildId, String userId) async {
    await _rpc('revoke_recruiter', {'p_guild': guildId, 'p_user': userId});
  }

  @override
  Future<void> report(String guildId, String reason) async {
    await _rpc('report_recruitment', {'p_guild': guildId, 'p_reason': reason});
  }
}

final recruitBackendProvider = Provider<RecruitBackend>((ref) => const SupabaseRecruitBackend());

/// a page of the list for a filter
final recruitListProvider = FutureProvider.autoDispose
    .family<RecruitList, RecruitFilter>((ref, filter) => ref.watch(recruitBackendProvider).list(filter));

/// the page of a guild
final recruitPageProvider = FutureProvider.autoDispose
    .family<RecruitPage?, String>((ref, guildId) => ref.watch(recruitBackendProvider).page(guildId));

/// the guilds whose page the player may manage. nothing for a player who is not signed in
final myRecruitProvider = FutureProvider.autoDispose<List<MyRecruitGuild>>((ref) async {
  if (!communityReady) return const [];
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return const [];
  return ref.watch(recruitBackendProvider).mine();
});

/// who the leader allowed to edit the page of a guild
final recruitersProvider = FutureProvider.autoDispose
    .family<List<RecruiterEntry>, String>((ref, guildId) => ref.watch(recruitBackendProvider).recruiters(guildId));
