import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/collections.dart';
import '../l10n/strings.dart';
import '../state/collections.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(s.t('collections_note'), style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
        const SizedBox(height: 12),
        CardWrap(minWidth: 340, children: [for (final kind in collectionKinds) _CollectionTile(kind: kind)]),
      ],
    );
  }
}

class _CollectionTile extends ConsumerWidget {
  const _CollectionTile({required this.kind});

  final CollectionKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final progress = ref.watch(collectionProgressProvider(kind.key));
    final p = progress.valueOrNull;

    return AppCard(
      onTap: kind.hasDetails
          ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => CollectionDetailScreen(kind: kind)),
              )
          : null,
      padding: const EdgeInsets.all(16),
      radius: AppRadius.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.t('col_${kind.key}'), style: display(18))),
              if (p != null)
                Text('${(p.ratio * 100).round()}%',
                    style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold)),
              if (kind.hasDetails) Icon(Icons.chevron_right, color: AppColors.chevron),
            ],
          ),
          const SizedBox(height: 4),
          if (progress.hasError)
            Text(s.t('needs_permission', {'p': 'unlocks'}), style: TextStyle(fontSize: 12, color: AppColors.muted))
          else if (p == null)
            LinearProgressIndicator(minHeight: 2, color: AppColors.gold)
          else ...[
            Text('${fmtInt(p.unlocked)} / ${fmtInt(p.total)}', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 10),
            Bar(value: p.ratio, color: p.ratio >= 1 ? AppColors.green : AppColors.gold),
          ],
        ],
      ),
    );
  }
}

class CollectionDetailScreen extends ConsumerStatefulWidget {
  const CollectionDetailScreen({super.key, required this.kind});

  final CollectionKind kind;

  @override
  ConsumerState<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends ConsumerState<CollectionDetailScreen> {
  // 0 all, 1 unlocked, 2 missing
  int _filter = 0;
  String _query = '';

  // wardrobe only: Armor, Weapon, Back or Gathering, then a slot or weapon
  String? _type;
  String? _subtype;

  // homestead decorations only: one of their categories
  String? _group;

  // on a site: the entry shown in full beside the wardrobe, and whether the missing ones lead
  String? _selected;
  var _missingFirst = false;

  String _typeLabel(S s, String type) => switch (type) {
        'Armor' => s.t('skin_armor'),
        'Weapon' => s.t('skin_weapon'),
        'Back' => s.t('skin_back'),
        'Gathering' => s.t('skin_gathering'),
        _ => titleCase(type),
      };

  /// the game marks some names with colour tags, which a page has no use for
  String _clean(String name) => name.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  Widget _ringBox(S s, List<CollectionEntry> all) {
    final done = all.where((e) => e.unlocked).length;
    final ratio = all.isEmpty ? 0.0 : done / all.length;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: ratio,
                  strokeWidth: 5,
                  backgroundColor: AppColors.track,
                  color: ratio >= 1 ? AppColors.green : AppColors.gold,
                ),
                Text('${(ratio * 100).round()}%', style: display(15)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmtInt(done), style: display(26)),
                Text('${s.t('of_n', {'n': fmtInt(all.length)})} · ${s.t('n_to_go', {'n': fmtInt(all.length - done)})}',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// the search, the three filters and the count, over every layout of a site
  Widget _siteToolbar(S s, List<CollectionEntry> list, {bool sortToggle = false}) => Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: fieldDecoration(s.t('search'), prefixIcon: Icon(Icons.search, color: AppColors.muted)),
            ),
          ),
          for (var i = 0; i < 3; i++)
            ChoiceChip(
              label: Text(s.t(['all', 'unlocked', 'missing'][i])),
              selected: _filter == i,
              onSelected: (_) => setState(() => _filter = i),
            ),
          if (sortToggle)
            ChoiceChip(
              label: Text(s.t('missing_first')),
              selected: _missingFirst,
              onSelected: (v) => setState(() => _missingFirst = v),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text('${fmtInt(list.where((e) => e.unlocked).length)} / ${fmtInt(list.length)}',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
        ],
      );

  /// a row of a list at the left of a page: a name and what is unlocked of it, dark while it is the one chosen
  Widget _sideRow(String label, String count, {required bool on, required VoidCallback onTap, bool sub = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Material(
          color: on ? AppColors.text : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(sub ? 28 : 14, 9, 14, 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: sub ? FontWeight.w600 : FontWeight.w700,
                            color: on ? AppColors.bg : AppColors.text)),
                  ),
                  Text(count,
                      style:
                          TextStyle(fontSize: 12, color: on ? AppColors.bg.withValues(alpha: 0.7) : AppColors.muted)),
                ],
              ),
            ),
          ),
        ),
      );

  String _tally(Iterable<CollectionEntry> es) => '${fmtInt(es.where((e) => e.unlocked).length)} / ${fmtInt(es.length)}';

  Widget _siteBody(S s, List<CollectionEntry> all, List<CollectionEntry> list,
      {required List<String> types, required List<String> subtypes, required List<String> groups}) {
    final key = widget.kind.key;
    // the wardrobe: a tree of what the skins are, the skins, the chosen one in full
    if (types.isNotEmpty) return _wardrobeSite(s, all, list, types, subtypes);
    // the decorations of a homestead, in a section for each category
    if (groups.isNotEmpty) return _groupsSite(s, all, list, groups);
    // titles and the like have no picture: a list to read
    final pictured = all.where((e) => e.icon != null && e.icon!.isNotEmpty).length;
    if (key == 'titles' || pictured < all.length / 2) return _listSite(s, all, list);
    return _gallerySite(s, all, list);
  }

  List<CollectionEntry> _ordered(List<CollectionEntry> list) {
    if (!_missingFirst) return list;
    return [...list.where((e) => !e.unlocked), ...list.where((e) => e.unlocked)];
  }

  Widget _tile(CollectionEntry e, {double size = 64, bool chosen = false, VoidCallback? onTap}) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: chosen
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.gold, width: 2))
              : null,
          child: Column(
            children: [
              Opacity(
                opacity: e.unlocked ? 1 : 0.35,
                child: ItemIcon(url: e.icon, rarity: e.unlocked ? (e.rarity ?? 'Exotic') : null, size: size),
              ),
              const SizedBox(height: 5),
              Text(e.name.isEmpty ? '#${e.id}' : _clean(e.name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, height: 1.25, color: e.unlocked ? AppColors.text : AppColors.muted)),
            ],
          ),
        ),
      );

  Widget _wardrobeSite(
      S s, List<CollectionEntry> all, List<CollectionEntry> list, List<String> types, List<String> subtypes) {
    final ordered = _ordered(list);
    final chosen = list.where((e) => e.id == _selected).firstOrNull ?? (list.isEmpty ? null : list.first);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 270,
            child: ListView(
              children: [
                _ringBox(s, all),
                const SizedBox(height: 12),
                _sideRow(s.t('all'), _tally(all),
                    on: _type == null,
                    onTap: () => setState(() {
                          _type = null;
                          _subtype = null;
                        })),
                for (final t in types) ...[
                  _sideRow(_typeLabel(s, t), _tally(all.where((e) => e.type == t)),
                      on: _type == t && _subtype == null,
                      onTap: () => setState(() {
                            _type = t;
                            _subtype = null;
                          })),
                  if (_type == t)
                    for (final sub in subtypes)
                      _sideRow(sub, _tally(all.where((e) => e.type == t && e.subtype?.split(' · ').first == sub)),
                          sub: true, on: _subtype == sub, onTap: () => setState(() => _subtype = sub)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _siteToolbar(s, list, sortToggle: true),
                const SizedBox(height: 12),
                Expanded(
                  child: Panel(
                    padding: const EdgeInsets.all(10),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 96,
                        mainAxisExtent: 108,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                      ),
                      itemCount: ordered.length,
                      itemBuilder: (context, i) => _tile(ordered[i],
                          chosen: ordered[i].id == chosen?.id, onTap: () => setState(() => _selected = ordered[i].id)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (chosen != null) ...[
            const SizedBox(width: 18),
            SizedBox(width: 310, child: _chosenPanel(s, chosen, all)),
          ],
        ],
      ),
    );
  }

  Widget _chosenPanel(S s, CollectionEntry e, List<CollectionEntry> all) {
    // the skins of the same name that the account lacks: a set is often named after one piece
    final base = e.name.split(' ').first;
    final others = [
      for (final o in all)
        if (!o.unlocked && o.id != e.id && o.name.startsWith('$base ') && o.type == e.type) o,
    ].take(4).toList();
    return Panel(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          Row(
            children: [
              Opacity(
                opacity: e.unlocked ? 1 : 0.5,
                child: ItemIcon(url: e.icon, rarity: e.unlocked ? (e.rarity ?? 'Exotic') : null, size: 84),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_clean(e.name), style: display(22)),
                    const SizedBox(height: 3),
                    Text([if (e.subtype != null) e.subtype!, if (e.rarity != null) e.rarity!].join(' · '),
                        style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(alignment: Alignment.centerLeft, child: Pill(s.t(e.unlocked ? 'unlocked' : 'missing'))),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(s.t('skins_missing_same'), style: TextStyle(fontSize: 13, color: AppColors.muted)),
            for (final o in others)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(o.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
          ],
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () => openUrl(
              context,
              'https://wiki.guildwars2.com/index.php?search=${Uri.encodeQueryComponent(e.name)}',
              failMessage: s.t('open_failed'),
            ),
            child: Text(s.t('wiki')),
          ),
        ],
      ),
    );
  }

  Widget _gallerySite(S s, List<CollectionEntry> all, List<CollectionEntry> list) {
    final ordered = _ordered(list);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [SizedBox(width: 340, child: _ringBox(s, all))]),
          const SizedBox(height: 12),
          _siteToolbar(s, list, sortToggle: true),
          const SizedBox(height: 12),
          Expanded(
            child: Panel(
              padding: const EdgeInsets.all(14),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 124,
                  mainAxisExtent: 128,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: ordered.length,
                itemBuilder: (context, i) => _tile(ordered[i], size: 76),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listSite(S s, List<CollectionEntry> all, List<CollectionEntry> list) {
    final ordered = _ordered(list);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [SizedBox(width: 340, child: _ringBox(s, all))]),
          const SizedBox(height: 12),
          _siteToolbar(s, list, sortToggle: true),
          const SizedBox(height: 12),
          Expanded(
            child: Panel(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                  mainAxisExtent: 44,
                  crossAxisSpacing: 28,
                ),
                itemCount: ordered.length,
                itemBuilder: (context, i) {
                  final e = ordered[i];
                  return Container(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.track))),
                    child: Row(
                      children: [
                        Icon(e.unlocked ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 20, color: e.unlocked ? AppColors.green : AppColors.hint),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(e.name.isEmpty ? s.t('unnamed_entry', {'id': e.id}) : _clean(e.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, color: e.unlocked ? AppColors.text : AppColors.muted)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupsSite(S s, List<CollectionEntry> all, List<CollectionEntry> list, List<String> groups) {
    final shownGroups = _group == null ? groups : [_group!];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 250,
            child: ListView(
              children: [
                _ringBox(s, all),
                const SizedBox(height: 12),
                _sideRow(s.t('all'), _tally(all), on: _group == null, onTap: () => setState(() => _group = null)),
                for (final g in groups)
                  _sideRow(g, _tally(all.where((e) => e.groups.contains(g))),
                      on: _group == g, onTap: () => setState(() => _group = g)),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _siteToolbar(s, list),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (final g in shownGroups)
                        if (list.any((e) => e.groups.contains(g)))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Panel(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(g, style: display(19))),
                                      Text(_tally(all.where((e) => e.groups.contains(g))),
                                          style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      // a section shows its first ones, a category can hold hundreds
                                      for (final e in list.where((e) => e.groups.contains(g)).take(48))
                                        SizedBox(width: 96, child: _tile(e, size: 56)),
                                    ],
                                  ),
                                  if (list.where((e) => e.groups.contains(g)).length > 48)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Text(
                                          s.t('n_more', {'n': list.where((e) => e.groups.contains(g)).length - 48}),
                                          style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final entries = ref.watch(collectionEntriesProvider(widget.kind.key));

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('col_${widget.kind.key}')),
      ),
      body: AsyncView<List<CollectionEntry>>(
        value: entries,
        onRetry: () => ref.invalidate(collectionEntriesProvider(widget.kind.key)),
        builder: (all) {
          final types = {
            for (final e in all)
              if (e.type != null) e.type!,
          }.toList()
            ..sort();
          final subtypes = <String>{
            for (final e in all)
              if (_type != null && e.type == _type && e.subtype != null) e.subtype!.split(' · ').first,
          }.toList()
            ..sort();
          final groups = <String>{
            for (final e in all) ...e.groups,
          }.toList()
            ..sort();
          final list = all.where((e) {
            if (_filter == 1 && !e.unlocked) return false;
            if (_filter == 2 && e.unlocked) return false;
            if (_type != null && e.type != _type) return false;
            if (_subtype != null && e.subtype?.split(' · ').first != _subtype) return false;
            if (_group != null && !e.groups.contains(_group)) return false;
            if (_query.isNotEmpty && !e.name.toLowerCase().contains(_query)) return false;
            return true;
          }).toList();
          final shown = list.where((e) => e.unlocked).length;
          if (SiteScope.of(context)) {
            return _siteBody(s, all, list, types: types, subtypes: subtypes, groups: groups);
          }
          Widget entry(CollectionEntry e) {
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Opacity(
                    opacity: e.unlocked ? 1 : 0.35,
                    child: ItemIcon(url: e.icon, rarity: e.unlocked ? (e.rarity ?? 'Exotic') : null, size: 40),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name.isEmpty ? s.t('unnamed_entry', {'id': e.id}) : e.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: e.unlocked ? AppColors.text : AppColors.muted,
                          ),
                        ),
                        if (e.subtype != null) Text(e.subtype!, style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  Icon(
                    e.unlocked ? Icons.check_circle : Icons.lock_outline,
                    size: 20,
                    color: e.unlocked ? AppColors.green : AppColors.hint,
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                      decoration: fieldDecoration(
                        s.t('search'),
                        prefixIcon: Icon(Icons.search, color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          ChoiceChip(
                            label: Text(s.t(['all', 'unlocked', 'missing'][i])),
                            selected: _filter == i,
                            onSelected: (_) => setState(() => _filter = i),
                          ),
                          if (i < 2) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    if (types.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _ChipRow(
                        labels: [s.t('all'), for (final t in types) _typeLabel(s, t)],
                        selected: _type == null ? 0 : types.indexOf(_type!) + 1,
                        onSelected: (i) => setState(() {
                          _type = i == 0 ? null : types[i - 1];
                          _subtype = null;
                        }),
                      ),
                    ],
                    if (subtypes.length > 1) ...[
                      const SizedBox(height: 8),
                      _ChipRow(
                        labels: [s.t('all'), ...subtypes],
                        selected: _subtype == null ? 0 : subtypes.indexOf(_subtype!) + 1,
                        onSelected: (i) => setState(() => _subtype = i == 0 ? null : subtypes[i - 1]),
                      ),
                    ],
                    if (groups.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _ChipRow(
                        labels: [s.t('all'), ...groups],
                        selected: _group == null ? 0 : groups.indexOf(_group!) + 1,
                        onSelected: (i) => setState(() => _group = i == 0 ? null : groups[i - 1]),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${fmtInt(shown)} / ${fmtInt(list.length)}',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                // on the site the entries are a grid of short tiles, as a collection is shown on a page
                child: SiteScope.of(context)
                    ? GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 290,
                          mainAxisExtent: 62,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, i) => entry(list[i]),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => entry(list[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// one line of choice chips that scrolls sideways
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ChoiceChip(
          label: Text(labels[i]),
          selected: selected == i,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => onSelected(i),
        ),
      ),
    );
  }
}
