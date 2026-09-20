import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'character_detail_screen.dart';

class CharactersScreen extends ConsumerStatefulWidget {
  const CharactersScreen({super.key});

  @override
  ConsumerState<CharactersScreen> createState() => _CharactersScreenState();
}

class _CharactersScreenState extends ConsumerState<CharactersScreen> {
  String _query = '';

  bool _matches(Json c) {
    if (_query.isEmpty) return true;
    final hay = '${c['name']} ${c['profession']} ${c['race']}'.toLowerCase();
    return hay.contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final chars = ref.watch(charactersProvider);
    final count = chars.valueOrNull?.length;

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async {
        ref.invalidate(charactersProvider);
        try {
          await ref.read(charactersProvider.future);
        } catch (_) {}
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(s.t('characters'), style: display(28))),
              if (count != null)
                Text(s.t('n_characters', {'n': count}),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: fieldDecoration(
              s.t('search_characters'),
              prefixIcon: const Icon(Icons.search, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 14),
          AsyncView<List<Json>>(
            value: chars,
            onRetry: () => ref.invalidate(charactersProvider),
            builder: (list) {
              final filtered = list.where(_matches).toList();
              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(s.t('no_match'), style: const TextStyle(color: AppColors.muted))),
                );
              }
              return Column(
                children: [
                  for (final c in filtered)
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: _CharacterCard(c)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CharacterCard extends ConsumerWidget {
  const _CharacterCard(this.c);

  final Json c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final name = '${c['name'] ?? ''}';
    final prof = '${c['profession'] ?? ''}';
    final color = professionColor(prof);
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => CharacterDetailScreen(name: name)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color, width: 2),
                ),
                child: Text(initial, style: display(22, color: color)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(prof, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                    const SizedBox(height: 2),
                    Text('${c['race'] ?? ''} · ${fmtHours(c['age'], s.t('hours_short'))}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(s.t('level_short'),
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppColors.muted)),
                  Text('${asInt(c['level'])}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Color(0xFF6E6859)),
            ],
          ),
        ),
      ),
    );
  }
}
