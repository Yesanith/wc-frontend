import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/gw2_api.dart';
import '../state/api.dart' show gw2ApiProvider;
import '../state/community.dart';
import '../state/navigation.dart';
import '../state/recruitment.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart' show Json;
import '../widgets/common.dart';
import '../widgets/guild_emblem.dart';
import '../widgets/responsive.dart';
import 'recruitment/editor_screen.dart';
import 'recruitment/page_screen.dart';
import 'recruitment/recruiters_screen.dart';

/// the guilds that are looking for players, in a list that anybody may read and that can be filtered by language, region and what is looked for, with the pages of the guilds the player
/// may manage above it. a page is opened to read how to reach the guild
/// the emblem of a guild as the game draws it, read with the guild's number in the game. it is public: no key is asked for
final recruitEmblemProvider = FutureProvider.family<Json?, String>((ref, gw2GuildId) async {
  if (gw2GuildId.isEmpty) return null;
  try {
    final guild = await ref.watch(gw2ApiProvider).guild(gw2GuildId);
    return guild['emblem'] is Map ? Map<String, dynamic>.from(guild['emblem'] as Map) : null;
  } catch (_) {
    // a guild without an emblem is shown with the shield
    return null;
  }
});

class RecruitmentScreen extends ConsumerStatefulWidget {
  const RecruitmentScreen({super.key});

  @override
  ConsumerState<RecruitmentScreen> createState() => _RecruitmentScreenState();
}

class _RecruitmentScreenState extends ConsumerState<RecruitmentScreen> {
  final _search = TextEditingController();
  String? _language;
  RecruitRegion? _region;
  String? _tag;
  bool _openOnly = false;
  String _text = '';

  /// how many guilds each page of the list skips: 0, then a page, then two
  List<int> _offsets = [0];

  RecruitFilter _filter(int offset) =>
      (language: _language, region: _region, lookingFor: _tag, search: _text, openOnly: _openOnly, offset: offset);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _change(VoidCallback change) => setState(() {
        change();
        _offsets = [0];
      });

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    if (!communityReady) return _Notice(text: s.t('rec_unavailable'));
    return ContentFrame(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(s.t('rec_intro'), style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSoft)),
          const SizedBox(height: 16),
          const _MyPages(),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: SiteScope.of(context) ? 420 : double.infinity),
              child: TextField(
                key: const Key('rec-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (text) => _change(() => _text = text.trim()),
                decoration: InputDecoration(
                  hintText: s.t('rec_search'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: s.t('cancel'),
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            _change(() => _text = '');
                          },
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ChipRow(children: [
            ChoiceChip(
                label: Text(s.t('all')),
                selected: _language == null,
                onSelected: (_) => _change(() => _language = null)),
            for (final code in recruitLanguages)
              ChoiceChip(
                  label: Text(recruitLanguageLabel(code)),
                  selected: _language == code,
                  onSelected: (_) => _change(() => _language = code)),
          ]),
          const SizedBox(height: 4),
          _ChipRow(children: [
            ChoiceChip(label: Text(s.t('all')), selected: _tag == null, onSelected: (_) => _change(() => _tag = null)),
            for (final tag in recruitTags)
              ChoiceChip(
                  label: Text(recruitTagLabel(s, tag)),
                  selected: _tag == tag,
                  onSelected: (_) => _change(() => _tag = tag)),
          ]),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                  label: Text(s.t('rec_region_any')),
                  selected: _region == null,
                  onSelected: (_) => _change(() => _region = null)),
              ChoiceChip(
                  label: Text(s.t('oe_region_eu')),
                  selected: _region == RecruitRegion.eu,
                  onSelected: (_) => _change(() => _region = RecruitRegion.eu)),
              ChoiceChip(
                  label: Text(s.t('oe_region_na')),
                  selected: _region == RecruitRegion.na,
                  onSelected: (_) => _change(() => _region = RecruitRegion.na)),
              FilterChip(
                  label: Text(s.t('rec_only_open')),
                  selected: _openOnly,
                  onSelected: (on) => _change(() => _openOnly = on)),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _offsets.length; i++)
            _ListPage(
              filter: _filter(_offsets[i]),
              first: i == 0,
              last: i == _offsets.length - 1,
              onMore: () => setState(() => _offsets = [..._offsets, _offsets.last + recruitPageSize]),
            ),
        ],
      ),
    );
  }
}

/// a row of chips that goes sideways when there are more than fit
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SiteScope.of(context)
      // a site has the width: the chips wrap onto a second line instead of hiding behind a scroll
      ? Wrap(spacing: 8, runSpacing: 8, children: children)
      : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [for (final c in children) Padding(padding: const EdgeInsets.only(right: 8), child: c)]),
        );
}

class _Notice extends ConsumerWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.4)),
        ),
      );
}

/// one page of the list, watched by itself so that the next is added under it and what is above is not asked for again
class _ListPage extends ConsumerWidget {
  const _ListPage({required this.filter, required this.first, required this.last, required this.onMore});

  final RecruitFilter filter;
  final bool first;
  final bool last;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final page = ref.watch(recruitListProvider(filter));
    return page.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(s.t(recruitErrorKey(e)), textAlign: TextAlign.center, style: TextStyle(color: AppColors.amber)),
            TextButton(onPressed: () => ref.invalidate(recruitListProvider), child: Text(s.t('retry'))),
          ],
        ),
      ),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (first && list.rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                  child: Text(s.t('rec_empty'), textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted))),
            ),
          for (final card in list.rows) _CardTile(card: card),
          if (last && filter.offset + list.rows.length < list.total && list.rows.length >= recruitPageSize)
            Align(child: TextButton(onPressed: onMore, child: Text(s.t('rec_more')))),
        ],
      ),
    );
  }
}

/// a guild of the list: its name, whether it is recruiting, its headline and what it looks for
class _CardTile extends ConsumerWidget {
  const _CardTile({required this.card});

  final RecruitCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    // on a site a guild is a row of its own: a badge at the left, what it says in the middle, where and when at the right
    if (SiteScope.of(context)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          onTap: () => showRecruitPage(context, card.guildId),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          radius: AppRadius.card,
          child: Row(
            children: [
              GuildEmblem(emblem: ref.watch(recruitEmblemProvider(card.gw2GuildId)).valueOrNull, size: 60),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                            child: Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(20))),
                        const SizedBox(width: 10),
                        Pill(card.recruiting ? s.t('rec_recruiting') : s.t('rec_closed'),
                            color: card.recruiting ? AppColors.green : null),
                      ],
                    ),
                    if (card.headline.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(card.headline,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [for (final t in card.lookingFor.take(5)) Pill(recruitTagLabel(s, t))],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 210,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      [
                        if (card.region != RecruitRegion.any) recruitRegionLabel(s, card.region),
                        for (final l in card.languages) recruitLanguageLabel(l),
                      ].join(' · '),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                    if (card.playTimes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(card.playTimes,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                        onPressed: () => showRecruitPage(context, card.guildId), child: Text(s.t('rec_view'))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    // a phone: the emblem at the left, the name large, where and in which languages under it, what it says, what it looks for
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => showRecruitPage(context, card.guildId),
        padding: const EdgeInsets.all(14),
        radius: AppRadius.card,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GuildEmblem(emblem: ref.watch(recruitEmblemProvider(card.gw2GuildId)).valueOrNull, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(19))),
                      const SizedBox(width: 8),
                      Pill(card.recruiting ? s.t('rec_recruiting') : s.t('rec_closed'),
                          color: card.recruiting ? AppColors.green : null),
                    ],
                  ),
                  Text(
                    [
                      if (card.region != RecruitRegion.any) recruitRegionLabel(s, card.region),
                      for (final l in card.languages) recruitLanguageLabel(l),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                  if (card.headline.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(card.headline,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.textSoft)),
                    ),
                  if (card.lookingFor.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [for (final t in card.lookingFor.take(4)) Pill(recruitTagLabel(s, t))],
                    ),
                  ],
                  if (card.playTimes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(card.playTimes, style: TextStyle(fontSize: 12, color: AppColors.hint)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// the guilds the player may manage the page of: where each page is, and the way to make it, change it, see it and, for the leader, say who else may. a player who is not signed in is told how to be
class _MyPages extends ConsumerWidget {
  const _MyPages();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final session = ref.watch(sessionProvider);
    if (session.valueOrNull == null) {
      // a visitor reads the list as anybody does, and is told once what signing in is for
      return session.isLoading
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                      child:
                          Text(s.t('rec_sign_in'), style: TextStyle(fontSize: 12, color: AppColors.hint, height: 1.4))),
                  TextButton(
                    onPressed: () => ref.read(sectionProvider.notifier).state = AppSection.settings,
                    child: Text(s.t('nav_settings')),
                  ),
                ],
              ),
            );
    }
    final mine = ref.watch(myRecruitProvider).valueOrNull ?? const <MyRecruitGuild>[];
    if (mine.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('rec_mine'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(s.t('rec_mine_hint'), style: TextStyle(fontSize: 12, color: AppColors.hint)),
          for (final g in mine) _MyGuild(guild: g),
        ],
      ),
    );
  }
}

class _MyGuild extends ConsumerWidget {
  const _MyGuild({required this.guild});

  final MyRecruitGuild guild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final (label, color) = switch (guild.status) {
      RecruitStatus.none => (s.t('rec_status_none'), AppColors.hint),
      RecruitStatus.draft => (s.t('rec_status_draft'), AppColors.amber),
      RecruitStatus.published => (s.t('rec_status_published'), AppColors.gold),
      RecruitStatus.stale => (s.t('rec_status_stale'), AppColors.amber),
      RecruitStatus.hidden => (s.t('rec_status_hidden'), AppColors.ember),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(guild.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => RecruitEditorScreen(guild: guild)));
                  if (!context.mounted) return;
                  ref.invalidate(myRecruitProvider);
                  ref.invalidate(recruitListProvider);
                },
                child: Text(guild.hasPage ? s.t('rec_edit') : s.t('rec_create')),
              ),
              if (guild.hasPage)
                TextButton(onPressed: () => showRecruitPage(context, guild.guildId), child: Text(s.t('rec_view'))),
              if (guild.isLeader)
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => RecruitersScreen(guild: guild))),
                  child: Text(s.t('rec_recruiters')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
