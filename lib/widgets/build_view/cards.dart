part of '../build_view.dart';

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
                      fontSize: 10, fontWeight: FontWeight.w700, color: selected ? AppColors.text : AppColors.muted)),
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
