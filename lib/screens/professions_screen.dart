import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../services/icon_cache.dart';
import '../state/api.dart';
import '../state/professions.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/class_icon.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';

/// every profession of the game with its specializations and weapons
class ProfessionsScreen extends ConsumerWidget {
  const ProfessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<Map<String, ProfessionInfo>>(
      value: ref.watch(professionsProvider),
      onRetry: () => ref.invalidate(professionsProvider),
      builder: (all) {
        final list = [
          for (final id in professionOrder)
            if (all[id] != null) all[id]!,
          // anything a future expansion adds
          for (final p in all.values)
            if (!professionOrder.contains(p.id)) p,
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [CardWrap(minWidth: 400, children: [for (final p in list) _ProfessionCard(p)])],
        );
      },
    );
  }
}

class _ProfessionCard extends StatelessWidget {
  const _ProfessionCard(this.p);

  final ProfessionInfo p;

  @override
  Widget build(BuildContext context) {
    final color = professionColor(p.id);
    final elites = p.specializations.where((l) => l['elite'] == true).toList();
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ProfessionDetailScreen(id: p.id)),
      ),
      padding: const EdgeInsets.all(14),
      radius: AppRadius.card,
      child: Row(
        children: [
          ProfessionIcon(url: p.iconBig ?? p.icon, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: display(18, color: color)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final e in elites) ...[
                      Tooltip(
                        message: '${e['name'] ?? ''}',
                        child: ProfessionIcon(url: e['profession_icon'] as String?, size: 22),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.chevron),
        ],
      ),
    );
  }
}

class ProfessionDetailScreen extends ConsumerWidget {
  const ProfessionDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final all = ref.watch(professionsProvider);
    final p = all.valueOrNull?[id];
    final color = professionColor(id);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(p?.name ?? id, style: display(20, color: color)),
      ),
      body: p == null
          ? AsyncView<Map<String, ProfessionInfo>>(
              value: all,
              onRetry: () => ref.invalidate(professionsProvider),
              builder: (_) => EmptyNote(s.t('nothing_here')),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                SectionHeader(title: s.t('specializations'), trailing: '${p.specializations.length}'),
                const SizedBox(height: 10),
                for (final line in p.specializations) _SpecTile(line: line, color: color),
                const SizedBox(height: 18),
                SectionHeader(title: s.t('weapons'), trailing: '${p.weapons.length}'),
                const SizedBox(height: 10),
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      for (final e in _sortedWeapons(p.weapons)) _WeaponRow(name: e.key, weapon: e.value, p: p, s: s),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

List<MapEntry<String, Json>> _sortedWeapons(Map<String, Json> weapons) {
  // weapons every build can use first, then the ones an elite line unlocks
  final list = weapons.entries.toList();
  list.sort((a, b) {
    final ea = asInt(a.value['specialization']) > 0;
    final eb = asInt(b.value['specialization']) > 0;
    if (ea != eb) return ea ? 1 : -1;
    return a.key.compareTo(b.key);
  });
  return list;
}

/// which hands a weapon goes in, from its flags
String weaponHands(S s, Json weapon) {
  final flags = {for (final f in (weapon['flags'] as List?) ?? const []) '$f'};
  return [
    if (flags.contains('TwoHand')) s.t('two_handed'),
    if (flags.contains('Mainhand')) s.t('main_hand'),
    if (flags.contains('Offhand')) s.t('off_hand'),
    if (flags.contains('Aquatic')) s.t('underwater'),
  ].join(' · ');
}

class _WeaponRow extends StatelessWidget {
  const _WeaponRow({required this.name, required this.weapon, required this.p, required this.s});

  final String name;
  final Json weapon;
  final ProfessionInfo p;
  final S s;

  @override
  Widget build(BuildContext context) {
    final line = p.specialization(asInt(weapon['specialization']));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleCase(professionWeaponKey(name)),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(weaponHands(s, weapon), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          if (line != null) ...[
            ProfessionIcon(url: line['profession_icon'] as String?, size: 18),
            const SizedBox(width: 6),
            Text('${line['name'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
          ],
        ],
      ),
    );
  }
}

/// one specialization, which opens to show its traits
class _SpecTile extends ConsumerStatefulWidget {
  const _SpecTile({required this.line, required this.color});

  final Json line;
  final Color color;

  @override
  ConsumerState<_SpecTile> createState() => _SpecTileState();
}

class _SpecTileState extends ConsumerState<_SpecTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final line = widget.line;
    final elite = line['elite'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => setState(() => _open = !_open),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: line['icon'] is String ? CachedIcon(url: line['icon'] as String, fit: BoxFit.contain) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      Text('${line['name'] ?? ''}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                if (elite) Pill(s.t('elite'), color: widget.color),
                Icon(_open ? Icons.expand_less : Icons.expand_more, color: AppColors.chevron),
              ],
            ),
            if (_open) _Traits(line: line),
          ],
        ),
      ),
    );
  }
}

class _Traits extends ConsumerWidget {
  const _Traits({required this.line});

  final Json line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final minors = intList(line['minor_traits']);
    final majors = intList(line['major_traits']);
    final traits = ref.watch(_traitsProvider([...minors, ...majors].join(',')));
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AsyncView<Map<int, Json>>(
        value: traits,
        onRetry: () => ref.invalidate(_traitsProvider([...minors, ...majors].join(','))),
        builder: (byId) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // three tiers, each a minor trait followed by its three majors
            for (var tier = 0; tier < 3; tier++) ...[
              Text(s.t('tier_n', {'n': tier + 1}),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted)),
              const SizedBox(height: 4),
              for (final id in [
                if (tier < minors.length) minors[tier],
                ...majors.skip(tier * 3).take(3),
              ])
                if (byId[id] != null) _TraitRow(trait: byId[id]!, minor: minors.contains(id)),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

final _traitsProvider = FutureProvider.autoDispose.family<Map<int, Json>, String>((ref, key) {
  final ids = [
    for (final part in key.split(','))
      if (int.tryParse(part) != null) int.parse(part),
  ];
  return ref.watch(gw2ApiProvider).traits(ids);
});

class _TraitRow extends StatelessWidget {
  const _TraitRow({required this.trait, required this.minor});

  final Json trait;
  final bool minor;

  @override
  Widget build(BuildContext context) {
    final description = '${trait['description'] ?? ''}'.replaceAll(RegExp(r'<[^>]*>'), '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: minor ? 0.7 : 1,
            child: SizedBox(
              width: 28,
              height: 28,
              child: trait['icon'] is String ? CachedIcon(url: trait['icon'] as String, fit: BoxFit.contain) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${trait['name'] ?? ''}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: minor ? FontWeight.w500 : FontWeight.w700,
                        color: minor ? AppColors.textSoft : AppColors.text)),
                if (description.isNotEmpty)
                  Text(description, style: const TextStyle(fontSize: 11, height: 1.35, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
