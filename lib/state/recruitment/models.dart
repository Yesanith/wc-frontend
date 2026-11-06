part of '../recruitment.dart';

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
      grantedAt: _time(raw['granted_at']),
    );
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
  }) => RecruitDraft(
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
    if (lookingFor.length > recruitLookingForMax || lookingFor.length + languages.length > recruitTagsMax)
      RecruitField.tags,
    if (languages.length > recruitLanguagesMax || languages.any((l) => !recruitLanguages.contains(l)))
      RecruitField.languages,
  ];

  /// what it takes to be shown to everybody: a headline, a description and a way to be reached
  List<RecruitField> missingToPublish() => [
    if (headline.trim().isEmpty) RecruitField.headline,
    if (description.trim().length < recruitDescriptionMin) RecruitField.description,
    if (discordInvite.trim().isEmpty && contact.trim().isEmpty) RecruitField.contact,
  ];
}

/// the fields of a page, for saying which one is not right
enum RecruitField {
  headline,
  description,
  requirements,
  playTimes,
  contact,
  discordInvite,
  lookingFor,
  languages,
  tags,
}

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
  int offset,
});

const noRecruitFilter = (language: null, region: null, lookingFor: null, search: '', openOnly: false, offset: 0);
