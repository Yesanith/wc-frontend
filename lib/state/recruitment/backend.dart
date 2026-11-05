part of '../recruitment.dart';

/// what the app asks of the database for recruitment. a pretend one in a test
abstract interface class RecruitBackend {
  Future<RecruitList> list(RecruitFilter filter);

  /// null when there is no page for whoever asks
  Future<RecruitPage?> page(String guildId);

  /// the guilds the player may manage the page of
  Future<List<MyRecruitGuild>> mine();
  Future<RecruitPage?> save(String guildId, RecruitDraft draft);
  Future<RecruitPage?> setPublished(String guildId, bool published);
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
