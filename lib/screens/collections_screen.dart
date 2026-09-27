import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/collections.dart';
import '../l10n/strings.dart';
import '../state/collections.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(s.t('collections_note'), style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
        const SizedBox(height: 12),
        for (final kind in collectionKinds)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CollectionTile(kind: kind),
          ),
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
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold)),
              if (kind.hasDetails) const Icon(Icons.chevron_right, color: AppColors.chevron),
            ],
          ),
          const SizedBox(height: 4),
          if (progress.hasError)
            Text(s.t('needs_permission', {'p': 'unlocks'}),
                style: const TextStyle(fontSize: 12, color: AppColors.muted))
          else if (p == null)
            const LinearProgressIndicator(minHeight: 2, color: AppColors.gold)
          else ...[
            Text('${fmtInt(p.unlocked)} / ${fmtInt(p.total)}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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

  String _typeLabel(S s, String type) => switch (type) {
        'Armor' => s.t('skin_armor'),
        'Weapon' => s.t('skin_weapon'),
        'Back' => s.t('skin_back'),
        'Gathering' => s.t('skin_gathering'),
        _ => titleCase(type),
      };

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final entries = ref.watch(collectionEntriesProvider(widget.kind.key));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('col_${widget.kind.key}'), style: display(20)),
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
          final list = all.where((e) {
            if (_filter == 1 && !e.unlocked) return false;
            if (_filter == 2 && e.unlocked) return false;
            if (_type != null && e.type != _type) return false;
            if (_subtype != null && e.subtype?.split(' · ').first != _subtype) return false;
            if (_query.isNotEmpty && !e.name.toLowerCase().contains(_query)) return false;
            return true;
          }).toList();
          final shown = list.where((e) => e.unlocked).length;

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
                        prefixIcon: const Icon(Icons.search, color: AppColors.muted),
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
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${fmtInt(shown)} / ${fmtInt(list.length)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final e = list[i];
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
                                if (e.subtype != null)
                                  Text(e.subtype!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
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
                  },
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
