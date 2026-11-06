import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/chat_code.dart';
import '../services/icon_cache.dart';
import '../state/builds.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import 'common.dart';

part 'build_view/cards.dart';
part 'build_view/skills.dart';

/// full view of one build: both trait rows of every line, the land and water
/// skill bars, pets or legends and the weapon skills of the profession
class BuildView extends ConsumerWidget {
  const BuildView({
    super.key,
    required this.buildData,
    this.padding = const EdgeInsets.all(20),
    this.weaponTypes = const [],
  });

  /// not named "build", that collides with the widget's own build method
  final Json buildData;
  final EdgeInsetsGeometry padding;

  /// weapon types the character currently carries, empty for stored builds
  final List<String> weaponTypes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final key = jsonEncode(buildData);
    final detail = ref.watch(buildDetailProvider(key));
    final profession = '${buildData['profession'] ?? ''}';
    final name = '${buildData['name'] ?? ''}'.trim();

    return AsyncView<BuildDetail>(
      value: detail,
      onRetry: () => ref.invalidate(buildDetailProvider(key)),
      builder: (d) {
        final landSkills = skillIdsOf(skillSet(buildData, aquatic: false));
        final waterSkills = skillIdsOf(skillSet(buildData, aquatic: true));
        final landPets = petIds(buildData, 'terrestrial');
        final waterPets = petIds(buildData, 'aquatic');
        final code = buildChatCode(buildData, d.profession, d.specs);

        return ListView(
          padding: padding,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 34,
                  decoration: BoxDecoration(color: professionColor(profession), borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? s.t('unnamed_build') : name, style: display(20)),
                      Text(
                        profession,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: professionColor(profession)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (code != null) ...[const SizedBox(height: 14), _ChatCodeRow(code: code)],
            const SizedBox(height: 18),
            SectionHeader(title: s.t('specializations')),
            const SizedBox(height: 10),
            for (final spec in (buildData['specializations'] as List?) ?? const [])
              if (spec is Map) ...[
                _SpecCard(spec: Map<String, dynamic>.from(spec), detail: d),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 14),
            SectionHeader(title: s.t('skill_bar')),
            const SizedBox(height: 10),
            _SkillList(ids: landSkills, detail: d),
            if (waterSkills.isNotEmpty) ...[
              const SizedBox(height: 14),
              SectionHeader(title: s.t('aquatic_skills')),
              const SizedBox(height: 10),
              _SkillList(ids: waterSkills, detail: d),
            ],
            if (d.legends.isNotEmpty) ...[
              const SizedBox(height: 14),
              SectionHeader(title: s.t('legends')),
              const SizedBox(height: 10),
              for (final legend in d.legends) ...[_LegendCard(legend: legend, detail: d), const SizedBox(height: 8)],
            ],
            if (landPets.isNotEmpty || waterPets.isNotEmpty) ...[
              const SizedBox(height: 14),
              SectionHeader(title: s.t('pets')),
              const SizedBox(height: 10),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    for (final id in landPets) _PetRow(pet: d.pets[id], label: s.t('pet')),
                    for (final id in waterPets) _PetRow(pet: d.pets[id], label: s.t('aquatic_pet')),
                  ],
                ),
              ),
            ],
            if (d.profession != null) ...[
              const SizedBox(height: 14),
              SectionHeader(title: s.t('weapon_skills')),
              const SizedBox(height: 10),
              _WeaponSkills(detail: d, only: weaponTypes),
            ],
          ],
        );
      },
    );
  }
}

class _ChatCodeRow extends ConsumerWidget {
  const _ChatCodeRow({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('chat_code'),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted),
                ),
                Text(
                  code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                Text(s.t('chat_code_note'), style: TextStyle(fontSize: 11, color: AppColors.hint)),
              ],
            ),
          ),
          IconButton(
            tooltip: s.t('copy'),
            icon: Icon(Icons.copy, color: AppColors.gold),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              showToast(context, s.t('copied'));
            },
          ),
        ],
      ),
    );
  }
}
