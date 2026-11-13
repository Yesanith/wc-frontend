import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/items.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import 'common.dart';

/// the objectives of one wizard's vault track, as returned by the api
class VaultObjectives extends ConsumerWidget {
  const VaultObjectives(this.data, {super.key, this.framed = true});

  final Json data;

  /// false inside a card that already draws its own frame
  final bool framed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final objectives = ((data['objectives'] as List?) ?? const []).whereType<Map>().toList();
    if (objectives.isEmpty) {
      return Panel(child: Text(s.t('vault_empty'), style: TextStyle(color: AppColors.muted)));
    }
    final list = Column(
      children: [
        VaultChestReward(data),
        for (var i = 0; i < objectives.length; i++)
          _ObjectiveRow(Map<String, dynamic>.from(objectives[i]), last: i == objectives.length - 1),
      ],
    );
    if (!framed) return list;
    return Panel(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: list);
  }
}

class _ObjectiveRow extends StatelessWidget {
  const _ObjectiveRow(this.o, {required this.last});

  final Json o;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final cur = asInt(o['progress_current']);
    final total = asInt(o['progress_complete']);
    final done = total > 0 && cur >= total;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: last ? Colors.transparent : AppColors.track)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // which part of the game the objective asks for
              Icon(_trackIcon('${o['track'] ?? ''}'), size: 16, color: done ? AppColors.muted : AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${o['title'] ?? ''}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: done ? AppColors.muted : AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$cur/$total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Bar(value: total == 0 ? 0 : cur / total, color: done ? AppColors.green : AppColors.gold),
        ],
      ),
    );
  }
}

IconData _trackIcon(String track) => switch (track) {
      'PvP' => Icons.sports_kabaddi,
      'WvW' => Icons.fort_outlined,
      _ => Icons.terrain_outlined,
    };

/// what the chest of a track gives when its meta bar is full: an item and astral acclaim, and whether it was taken already.
/// nothing for a track that has no chest, such as the special one
class VaultChestReward extends ConsumerWidget {
  const VaultChestReward(this.data, {super.key});

  final Json data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemId = asInt(data['meta_reward_item_id']);
    final astral = asInt(data['meta_reward_astral']);
    if (itemId == 0 && astral == 0) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    final item = itemId == 0 ? null : ref.watch(itemProvider(itemId)).valueOrNull;
    final goal = asInt(data['meta_progress_complete']);
    final reached = goal > 0 && asInt(data['meta_progress_current']) >= goal;
    final claimed = data['meta_reward_claimed'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.track))),
      child: Row(
        children: [
          ItemIcon(url: item?['icon'] as String?, rarity: item?['rarity'] as String?, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('vault_chest_reward').caps,
                    style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.muted)),
                Text(
                  [
                    if (item != null) '${item['name']}',
                    if (astral > 0) '+$astral ${s.t('astral_acclaim')}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (claimed)
            Icon(Icons.check_circle, size: 20, color: AppColors.green)
          else if (reached)
            Pill(s.t('vault_chest_ready'))
          else
            Icon(Icons.lock_outline, size: 18, color: AppColors.hint),
        ],
      ),
    );
  }
}
