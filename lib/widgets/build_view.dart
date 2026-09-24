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
                      Text(name.isEmpty ? s.t('unnamed_build') : name, style: display(20)),
                      Text(profession,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: professionColor(profession))),
                    ],
                  ),
                ),
              ],
            ),
            if (code != null) ...[
              const SizedBox(height: 14),
              _ChatCodeRow(code: code),
            ],
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
              for (final legend in d.legends) ...[
                _LegendCard(legend: legend, detail: d),
                const SizedBox(height: 8),
              ],
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
                Text(s.t('chat_code'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted)),
                Text(code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                Text(s.t('chat_code_note'), style: const TextStyle(fontSize: 11, color: AppColors.hint)),
              ],
            ),
          ),
          IconButton(
            tooltip: s.t('copy'),
            icon: const Icon(Icons.copy, color: AppColors.gold),
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

class _SpecCard extends StatelessWidget {
  const _SpecCard({required this.spec, required this.detail});

  final Json spec;
  final BuildDetail detail;

  @override
  Widget build(BuildContext context) {
    final specId = asInt(spec['id']);
    final info = detail.specs[specId];
    final name = (info?['name'] as String?) ?? '#$specId';
    final elite = info?['elite'] == true;
    final chosen = intList(spec['traits']).toSet();
    final majors = intList(info?['major_traits']);
    final minors = intList(info?['minor_traits']);

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
                      ? CachedIcon(url: info!['icon'] as String)
                      : const ColoredBox(color: AppColors.surface2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
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
          for (var tier = 0; tier < 3; tier++) ...[
            const SizedBox(height: 12),
            if (tier < minors.length) _MinorTrait(trait: detail.traits[minors[tier]]),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var slot = 0; slot < 3; slot++)
                  if (tier * 3 + slot < majors.length) ...[
                    Expanded(
                      child: _MajorTrait(
                        trait: detail.traits[majors[tier * 3 + slot]],
                        selected: chosen.contains(majors[tier * 3 + slot]),
                      ),
                    ),
                    if (slot < 2) const SizedBox(width: 6),
                  ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MinorTrait extends StatelessWidget {
  const _MinorTrait({required this.trait});

  final Json? trait;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ItemIcon(url: trait?['icon'] as String?, rarity: 'Rare', size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text((trait?['name'] as String?) ?? '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.muted)),
        ),
      ],
    );
  }
}

class _MajorTrait extends StatelessWidget {
  const _MajorTrait({required this.trait, required this.selected});

  final Json? trait;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final data = trait;
    final name = (data?['name'] as String?) ?? '-';
    return GestureDetector(
      onTap: data == null ? null : () => showSkillSheet(context, data),
      child: Opacity(
        opacity: selected ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.gold : AppColors.line),
          ),
          child: Column(
            children: [
              ItemIcon(url: data?['icon'] as String?, rarity: selected ? 'Exotic' : null, size: 30),
              const SizedBox(height: 5),
              Text(name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.text : AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillList extends ConsumerWidget {
  const _SkillList({required this.ids, required this.detail});

  final List<int> ids;
  final BuildDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < ids.length; i++)
            SkillRow(
              skill: detail.skills[ids[i]],
              detail: detail,
              slot: i == 0
                  ? s.t('heal_skill')
                  : i == ids.length - 1
                      ? s.t('elite_skill')
                      : s.t('utility_skill'),
            ),
        ],
      ),
    );
  }
}

class _LegendCard extends StatelessWidget {
  const _LegendCard({required this.legend, required this.detail});

  final Json legend;
  final BuildDetail detail;

  @override
  Widget build(BuildContext context) {
    final swap = detail.skills[asInt(legend['swap'])];
    final name = (swap?['name'] as String?) ?? '${legend['id']}';
    final ids = <int>[
      asInt(legend['heal']),
      ...intList(legend['utilities']),
      asInt(legend['elite']),
    ].where((id) => id > 0).toList();

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ItemIcon(url: swap?['icon'] as String?, rarity: 'Exotic', size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
            ],
          ),
          for (final id in ids) SkillRow(skill: detail.skills[id], detail: detail, slot: ''),
        ],
      ),
    );
  }
}

class _PetRow extends StatelessWidget {
  const _PetRow({required this.pet, required this.label});

  final Json? pet;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ItemIcon(url: pet?['icon'] as String?, rarity: 'Exotic', size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.muted)),
                Text((pet?['name'] as String?) ?? '-',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// weapon skill bars from the profession endpoint. [only] narrows it to the
/// weapons a character actually carries
class _WeaponSkills extends StatelessWidget {
  const _WeaponSkills({required this.detail, required this.only});

  final BuildDetail detail;
  final List<String> only;

  @override
  Widget build(BuildContext context) {
    final weapons = detail.profession?['weapons'];
    if (weapons is! Map || weapons.isEmpty) return const SizedBox.shrink();
    final names = weapons.keys.map((e) => '$e').where((w) => only.isEmpty || only.contains(w)).toList()..sort();
    if (names.isEmpty) return const SizedBox.shrink();

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          for (final weapon in names)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                iconColor: AppColors.gold,
                collapsedIconColor: AppColors.muted,
                title: Text(weapon, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                children: [
                  for (final entry in ((weapons[weapon] as Map)['skills'] as List?) ?? const [])
                    if (entry is Map)
                      _WeaponSkillRow(
                        id: asInt(entry['id']),
                        slot: '${entry['slot'] ?? ''}',
                        detail: detail,
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WeaponSkillRow extends ConsumerWidget {
  const _WeaponSkillRow({required this.id, required this.slot, required this.detail});

  final int id;
  final String slot;
  final BuildDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skill = ref.watch(skillProvider(id)).valueOrNull;
    if (skill == null) return const SizedBox.shrink();
    return SkillRow(skill: skill, detail: detail, slot: slot);
  }
}

/// one skill with its numbers, plus its toolbelt or chained follow up
class SkillRow extends ConsumerWidget {
  const SkillRow({super.key, required this.skill, required this.detail, required this.slot, this.depth = 0});

  final Json? skill;
  final BuildDetail detail;
  final String slot;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final data = skill;
    if (data == null) return const SizedBox.shrink();
    final description = '${data['description'] ?? ''}'.replaceAll(RegExp(r'<[^>]*>'), '');
    final facts = factLines(data);
    final chain = asInt(data['next_chain']);
    final toolbelt = asInt(data['toolbelt_skill']);

    return Padding(
      padding: EdgeInsets.fromLTRB(depth * 16.0, 8, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => showSkillSheet(context, data),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ItemIcon(url: data['icon'] as String?, rarity: 'Exotic', size: depth > 0 ? 26 : 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (slot.isNotEmpty)
                        Text(slot.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: AppColors.muted)),
                      Text((data['name'] as String?) ?? '-',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      if (description.isNotEmpty)
                        Text(description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, height: 1.35, color: AppColors.muted)),
                      if (facts.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [for (final f in facts.take(6)) Pill(f)],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (toolbelt > 0 && detail.skills[toolbelt] != null)
            SkillRow(skill: detail.skills[toolbelt], detail: detail, slot: s.t('toolbelt'), depth: depth + 1),
          if (chain > 0 && detail.skills[chain] != null && depth < 2)
            SkillRow(skill: detail.skills[chain], detail: detail, slot: s.t('chain'), depth: depth + 1),
        ],
      ),
    );
  }
}

/// turns the api fact objects into short "Recharge: 20s" style lines
List<String> factLines(Json data) {
  final out = <String>[];
  for (final raw in (data['facts'] as List?) ?? const []) {
    if (raw is! Map) continue;
    final text = '${raw['text'] ?? raw['status'] ?? ''}'.trim();
    final type = '${raw['type'] ?? ''}';
    if (type == 'Recharge' && raw['value'] != null) {
      out.add('${text.isEmpty ? 'Recharge' : text}: ${raw['value']}s');
      continue;
    }
    final parts = <String>[];
    if (text.isNotEmpty) parts.add(text);
    if (raw['value'] != null) parts.add('${raw['value']}');
    if (raw['percent'] != null) parts.add('${raw['percent']}%');
    if (raw['duration'] != null) parts.add('${raw['duration']}s');
    if (raw['apply_count'] != null && asInt(raw['apply_count']) > 1) parts.add('x${raw['apply_count']}');
    if (parts.isEmpty) continue;
    out.add(parts.length == 1 ? parts.first : '${parts.first}: ${parts.sublist(1).join(' ')}');
  }
  return out;
}

void showSkillSheet(BuildContext context, Json data) {
  final description = '${data['description'] ?? ''}'.replaceAll(RegExp(r'<[^>]*>'), '');
  final facts = factLines(data);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ItemIcon(url: data['icon'] as String?, rarity: 'Exotic', size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text((data['name'] as String?) ?? '-',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSoft)),
            ],
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final f in facts) Pill(f)]),
            ],
          ],
        ),
      ),
    ),
  );
}
