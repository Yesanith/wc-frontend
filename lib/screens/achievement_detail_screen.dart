import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/progression.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import '../widgets/pin_button.dart';

/// one achievement: what it asks, how far the account is, the pieces of it that are a collection with which ones are still
/// missing, its tiers and its rewards
class AchievementDetailScreen extends ConsumerWidget {
  const AchievementDetailScreen({super.key, required this.row});

  final AchievementRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final description = '${row.detail?['description'] ?? ''}'.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final requirement = '${row.detail?['requirement'] ?? ''}'.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final tiers = [
      for (final t in (row.detail?['tiers'] as List?) ?? const [])
        if (t is Map) t,
    ];
    final extras = ref.watch(achievementExtrasProvider(row.id));
    final hasBits = ((row.detail?['bits'] as List?) ?? const []).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(row.name),
        actions: [if (!row.done) AchievementPinButton(id: row.id)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Row(
            children: [
              Icon(row.done ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20, color: row.done ? AppColors.green : AppColors.track),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  row.done
                      ? s.t('ach_done')
                      : row.max > 0
                          ? '${fmtInt(row.current)} / ${fmtInt(row.max)}'
                          : s.t('ach_not_started'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              if (row.points > 0) Pill(s.t('ach_points_n', {'n': row.points})),
            ],
          ),
          if (!row.done && row.max > 0) ...[const SizedBox(height: 10), Bar(value: row.ratio)],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(description, style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSoft)),
          ],
          if (requirement.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(requirement, style: const TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w600)),
          ],
          if (hasBits)
            AsyncView<AchievementExtras>(
              value: extras,
              onRetry: () => ref.invalidate(achievementExtrasProvider(row.id)),
              builder: (data) => _Pieces(bits: data.bits, done: row.bitsDone.toSet()),
            ),
          if (tiers.length > 1) ...[
            const SizedBox(height: 22),
            SectionHeader(title: s.t('ach_tiers')),
            const SizedBox(height: 8),
            for (var i = 0; i < tiers.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(row.current >= asInt(tiers[i]['count']) ? Icons.check_circle : Icons.circle_outlined,
                        size: 16, color: row.current >= asInt(tiers[i]['count']) ? AppColors.green : AppColors.track),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(fmtInt(asInt(tiers[i]['count'])), style: const TextStyle(fontSize: 13)),
                    ),
                    Text(s.t('ach_points_n', {'n': asInt(tiers[i]['points'])}),
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
          ],
          AsyncView<AchievementExtras>(
            value: extras,
            onRetry: () => ref.invalidate(achievementExtrasProvider(row.id)),
            builder: (data) => data.rewards.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 22),
                      SectionHeader(title: s.t('ach_rewards')),
                      const SizedBox(height: 8),
                      for (final r in data.rewards)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              if (r.icon != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: ItemIcon(url: r.icon, size: 28),
                                ),
                              if (r.kind == 'Coins')
                                CoinText(r.copper, size: 14)
                              else
                                Expanded(
                                  child: Text(
                                    switch (r.kind) {
                                      'Title' => s.t('ach_reward_title', {'name': r.label}),
                                      'Mastery' => s.t('ach_reward_mastery', {'region': r.label}),
                                      _ => r.label,
                                    },
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
}

/// the pieces of a collection, the missing ones first
class _Pieces extends ConsumerWidget {
  const _Pieces({required this.bits, required this.done});

  final List<AchievementBit> bits;
  final Set<int> done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (bits.isEmpty) return const SizedBox.shrink();
    final order = [for (var i = 0; i < bits.length; i++) i]
      ..sort((a, b) => (done.contains(a) ? 1 : 0).compareTo(done.contains(b) ? 1 : 0));
    final have = done.where((i) => i >= 0 && i < bits.length).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        SectionHeader(title: s.t('ach_pieces'), trailing: s.t('ach_pieces_have', {'a': have, 'b': bits.length})),
        const SizedBox(height: 4),
        for (final i in order)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Opacity(
              opacity: done.contains(i) ? 0.55 : 1,
              child: Row(
                children: [
                  if (bits[i].icon != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ItemIcon(url: bits[i].icon, size: 30),
                    )
                  else
                    const SizedBox(width: 40),
                  Expanded(
                    child: Text(bits[i].name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  Icon(done.contains(i) ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 18, color: done.contains(i) ? AppColors.green : AppColors.muted),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
