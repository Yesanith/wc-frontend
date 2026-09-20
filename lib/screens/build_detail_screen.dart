import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

/// full view of one build: the three lines with their chosen traits, the
/// skill bar and, for rangers, the pets
class BuildView extends ConsumerWidget {
  const BuildView({super.key, required this.build, this.padding = const EdgeInsets.all(20)});

  final Json build;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final key = buildKey(build);
    final detail = ref.watch(buildDetailProvider(key));
    final profession = '${build['profession'] ?? ''}';
    final skills = build['skills'] is Map ? build['skills'] as Map : const {};

    return AsyncView<BuildDetail>(
      value: detail,
      onRetry: () => ref.invalidate(buildDetailProvider(key)),
      builder: (d) {
        final skillIds = <int>[
          asInt(skills['heal']),
          for (final u in (skills['utilities'] as List?) ?? const []) asInt(u),
          asInt(skills['elite']),
        ];
        final petIds = [
          for (final p in (build['pets'] as List?) ?? const [])
            if (p != null) asInt(p),
        ];

        return ListView(
          padding: padding,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 34,
                  decoration: BoxDecoration(
                    color: professionColor(profession),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${build['name'] ?? ''}'.trim().isEmpty ? s.t('unnamed_build') : '${build['name']}',
                          style: display(20)),
                      Text(profession,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: professionColor(profession))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SectionHeader(title: s.t('specializations')),
            const SizedBox(height: 10),
            for (final spec in (build['specializations'] as List?) ?? const [])
              if (spec is Map) ...[
                _SpecCard(spec: Map<String, dynamic>.from(spec), detail: d),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 14),
            SectionHeader(title: s.t('skill_bar')),
            const SizedBox(height: 10),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < skillIds.length; i++)
                    if (skillIds[i] > 0)
                      _SkillRow(
                        skill: d.skills[skillIds[i]],
                        label: i == 0
                            ? s.t('heal_skill')
                            : i == skillIds.length - 1
                                ? s.t('elite_skill')
                                : s.t('utility_skill'),
                      ),
                ],
              ),
            ),
            if (petIds.isNotEmpty) ...[
              const SizedBox(height: 14),
              SectionHeader(title: s.t('pets')),
              const SizedBox(height: 10),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    for (final id in petIds)
                      _SkillRow(skill: d.pets[id], label: s.t('pet')),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SpecCard extends StatelessWidget {
  const _SpecCard({required this.spec, required this.detail});

  final Json spec;
  final BuildDetail detail;

  @override
  Widget build(BuildContext context) {
    final info = detail.specs[asInt(spec['id'])];
    final name = (info?['name'] as String?) ?? '#${spec['id']}';
    final elite = info?['elite'] == true;
    final traitIds = [
      for (final t in (spec['traits'] as List?) ?? const [])
        if (t != null) asInt(t),
    ];

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: info?['icon'] is String
                      ? Image.network(info!['icon'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => const ColoredBox(color: AppColors.surface2))
                      : const ColoredBox(color: AppColors.surface2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              if (elite)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.gold),
                  ),
                  child: const Text('ELITE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.gold)),
                ),
            ],
          ),
          for (final id in traitIds) ...[
            const SizedBox(height: 10),
            _TraitRow(trait: detail.traits[id]),
          ],
        ],
      ),
    );
  }
}

class _TraitRow extends StatelessWidget {
  const _TraitRow({required this.trait});

  final Json? trait;

  @override
  Widget build(BuildContext context) {
    final name = (trait?['name'] as String?) ?? '-';
    final description = '${trait?['description'] ?? ''}'.replaceAll(RegExp(r'<[^>]*>'), '');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ItemIcon(url: trait?['icon'] as String?, rarity: 'Exotic', size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              if (description.isNotEmpty)
                Text(description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, height: 1.35, color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.skill, required this.label});

  final Json? skill;
  final String label;

  @override
  Widget build(BuildContext context) {
    final name = (skill?['name'] as String?) ?? '-';
    final description = '${skill?['description'] ?? ''}'.replaceAll(RegExp(r'<[^>]*>'), '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ItemIcon(url: skill?['icon'] as String?, rarity: 'Exotic', size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.muted)),
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                if (description.isNotEmpty)
                  Text(description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, height: 1.35, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BuildDetailScreen extends ConsumerWidget {
  const BuildDetailScreen({super.key, required this.build});

  final Json build;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('build'), style: display(20)),
      ),
      body: BuildView(build: build, padding: const EdgeInsets.fromLTRB(20, 8, 20, 24)),
    );
  }
}
