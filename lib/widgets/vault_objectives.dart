import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      return Panel(child: Text(s.t('vault_empty'), style: const TextStyle(color: AppColors.muted)));
    }
    final list = Column(
      children: [
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
              Text('$cur/$total',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Bar(value: total == 0 ? 0 : cur / total, color: done ? AppColors.green : AppColors.gold),
        ],
      ),
    );
  }
}
