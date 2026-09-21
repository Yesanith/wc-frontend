import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/characters.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

/// two characters next to each other, useful when deciding which one to
/// gear up next
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key, required this.first});

  final String first;

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  String? _second;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final chars = ref.watch(charactersProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('compare'), style: display(20)),
      ),
      body: AsyncView<List<Json>>(
        value: chars,
        onRetry: () => ref.invalidate(charactersProvider),
        builder: (list) {
          final left = characterByName(list, widget.first);
          final others = list.where((c) => '${c['name']}' != widget.first).toList();
          final secondName = _second ?? (others.isEmpty ? null : '${others.first['name']}');
          final right = secondName == null ? null : characterByName(list, secondName);
          if (left == null || right == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(s.t('need_two_characters'), style: const TextStyle(color: AppColors.muted))),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in others) ...[
                      ChoiceChip(
                        label: Text('${c['name']}'),
                        selected: secondName == '${c['name']}',
                        onSelected: (_) => setState(() => _second = '${c['name']}'),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _Head(c: left)),
                  const SizedBox(width: 10),
                  Expanded(child: _Head(c: right)),
                ],
              ),
              const SizedBox(height: 16),
              _CompareRow(label: s.t('level'), left: '${asInt(left['level'])}', right: '${asInt(right['level'])}'),
              _CompareRow(
                label: s.t('playtime'),
                left: fmtHours(left['age'], s.t('hours_short')),
                right: fmtHours(right['age'], s.t('hours_short')),
              ),
              _CompareRow(
                label: s.t('deaths'),
                left: fmtInt(asInt(left['deaths'])),
                right: fmtInt(asInt(right['deaths'])),
              ),
              _CompareRow(label: s.t('race'), left: '${left['race'] ?? ''}', right: '${right['race'] ?? ''}'),
              _CompareRow(
                label: s.t('crafting'),
                left: _crafting(left),
                right: _crafting(right),
              ),
              const SizedBox(height: 16),
              SectionHeader(title: s.t('equipment')),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _GearSummary(c: left)),
                  const SizedBox(width: 10),
                  Expanded(child: _GearSummary(c: right)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

String _crafting(Json c) {
  final rows = ((c['crafting'] as List?) ?? const []).whereType<Map>().toList();
  if (rows.isEmpty) return '-';
  return rows.map((r) => '${r['discipline']} ${asInt(r['rating'])}').join('\n');
}

class _Head extends StatelessWidget {
  const _Head({required this.c});

  final Json c;

  @override
  Widget build(BuildContext context) {
    final profession = '${c['profession'] ?? ''}';
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${c['name'] ?? ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: display(16)),
          Text(profession,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: professionColor(profession))),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.label, required this.left, required this.right});

  final String label;
  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.muted)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(left, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.4)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.4)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// how many pieces of each rarity the character wears
class _GearSummary extends ConsumerWidget {
  const _GearSummary({required this.c});

  final Json c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(characterItemsProvider('${c['name']}')).valueOrNull ?? const <int, Json>{};
    final counts = <String, int>{};
    for (final e in activeEquipment(c)) {
      final rarity = items[asInt(e['id'])]?['rarity'] as String?;
      if (rarity == null) continue;
      counts[rarity] = (counts[rarity] ?? 0) + 1;
    }
    final order = ['Legendary', 'Ascended', 'Exotic', 'Rare', 'Masterwork', 'Fine', 'Basic'];

    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final rarity in order)
            if ((counts[rarity] ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: rarityColor(rarity), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(rarity, style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
                    ),
                    Text('${counts[rarity]}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
          if (counts.isEmpty)
            Text('-', style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}
