import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/community.dart';
import '../state/navigation.dart';
import '../state/recruitment.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/responsive.dart';
import 'recruitment/editor_screen.dart';
import 'recruitment/page_screen.dart';
import 'recruitment/recruiters_screen.dart';

/// the guilds that are looking for players, in a list that anybody may read and that can be filtered by language, region and what is looked for, with the pages of the guilds the player
/// may manage above it. a page is opened to read how to reach the guild
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
          TextField(
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
  Widget build(BuildContext context) => SingleChildScrollView(
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
                  child: Text(s.t('rec_empty'),
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted))),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => showRecruitPage(context, card.guildId),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(card.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                    Text(
                      card.recruiting ? s.t('rec_recruiting') : s.t('rec_closed'),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: card.recruiting ? AppColors.gold : AppColors.hint),
                    ),
                  ],
                ),
                if (card.headline.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(card.headline, style: TextStyle(fontSize: 13, color: AppColors.textSoft))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final t in card.lookingFor.take(4)) _Mini(recruitTagLabel(s, t)),
                    for (final l in card.languages) _Mini(recruitLanguageLabel(l)),
                    if (card.region != RecruitRegion.any) _Mini(recruitRegionLabel(s, card.region)),
                  ],
                ),
                if (card.playTimes.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(card.playTimes, style: TextStyle(fontSize: 12, color: AppColors.hint))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.line)),
        child: Text(text, style: TextStyle(fontSize: 11, color: AppColors.muted)),
      );
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
                      child: Text(s.t('rec_sign_in'),
                          style: TextStyle(fontSize: 12, color: AppColors.hint, height: 1.4))),
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
