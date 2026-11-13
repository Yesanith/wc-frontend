part of '../build_view.dart';

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
                        Text(slot.caps,
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.muted)),
                      Text((data['name'] as String?) ?? '-',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      if (description.isNotEmpty)
                        Text(description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, height: 1.35, color: AppColors.muted)),
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
              Text(description, style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSoft)),
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
