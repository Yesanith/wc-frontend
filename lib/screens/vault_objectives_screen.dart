import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/settings.dart';
import '../state/vault.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import 'vault_shop_screen.dart';

/// the two buttons at the head of a vault track: everything it can ask for this season, and the shop its acclaim buys from
class VaultHeaderActions extends ConsumerWidget {
  const VaultHeaderActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: s.t('vault_objectives_all'),
          visualDensity: VisualDensity.compact,
          onPressed: () => openPanel(context, (_) => const VaultObjectivesScreen()),
          icon: Icon(Icons.checklist_rounded, color: AppColors.gold, size: 20),
        ),
        IconButton(
          tooltip: s.t('vault_shop'),
          visualDensity: VisualDensity.compact,
          onPressed: () => openPanel(context, (_) => const VaultShopScreen()),
          icon: Icon(Icons.storefront_outlined, color: AppColors.gold, size: 20),
        ),
      ],
    );
  }
}

/// every objective of the season by track, with the acclaim each pays, and a box to look one up
class VaultObjectivesScreen extends ConsumerStatefulWidget {
  const VaultObjectivesScreen({super.key});

  @override
  ConsumerState<VaultObjectivesScreen> createState() => _VaultObjectivesScreenState();
}

class _VaultObjectivesScreenState extends ConsumerState<VaultObjectivesScreen> {
  final _ctrl = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final season = ref.watch(vaultSeasonProvider).valueOrNull;
    final end = DateTime.tryParse('${season?['end'] ?? ''}')?.toLocal();
    return Scaffold(
      appBar: AppBar(surfaceTintColor: Colors.transparent, title: Text(s.t('vault_objectives_all'))),
      body: AsyncView<List<Json>>(
        value: ref.watch(vaultObjectivesProvider),
        onRetry: () => ref.invalidate(vaultObjectivesProvider),
        builder: (all) {
          final q = _query.trim().toLowerCase();
          final shown = [
            for (final o in all)
              if (q.isEmpty || '${o['title']}'.toLowerCase().contains(q)) o,
          ];
          final tracks = <String>[
            for (final o in shown)
              if (!['PvE', 'PvP', 'WvW'].contains('${o['track']}')) '${o['track']}',
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              if (season != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    [
                      '${season['title'] ?? ''}',
                      if (end != null) s.t('season_ends', {'d': '${end.day}.${end.month}.${end.year}'}),
                    ].where((e) => e.isNotEmpty).join(' · '),
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
              Text(s.t('vault_objectives_note', {'n': all.length}),
                  style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSoft)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: SiteScope.of(context) ? 420 : double.infinity),
                  child: TextField(
                    controller: _ctrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: fieldDecoration(
                      s.t('vault_objectives_search'),
                      prefixIcon: Icon(Icons.search, color: AppColors.gold),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(Icons.close, color: AppColors.muted),
                              onPressed: () {
                                _ctrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ),
              ),
              if (shown.isEmpty) Padding(padding: const EdgeInsets.only(top: 20), child: EmptyNote(s.t('no_results'))),
              for (final track in ['PvE', 'PvP', 'WvW', ...tracks.toSet()]) ...[
                if (shown.any((o) => '${o['track']}' == track)) ...[
                  const SizedBox(height: 18),
                  SectionHeader(title: track, trailing: '${shown.where((o) => '${o['track']}' == track).length}'),
                  const SizedBox(height: 4),
                  for (final o in shown.where((o) => '${o['track']}' == track))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${o['title']}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 10),
                          Pill('+${asInt(o['acclaim'])}'),
                        ],
                      ),
                    ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
