import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';

class MapsScreen extends ConsumerStatefulWidget {
  const MapsScreen({super.key});

  @override
  ConsumerState<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends ConsumerState<MapsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final maps = ref.watch(mapsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: fieldDecoration(
              s.t('search_maps'),
              prefixIcon: const Icon(Icons.search, color: AppColors.muted),
            ),
          ),
        ),
        Expanded(
          child: AsyncView<List<GameMap>>(
            value: maps,
            onRetry: () => ref.invalidate(mapsProvider),
            builder: (list) {
              final filtered = list
                  .where((m) =>
                      m.name.isNotEmpty &&
                      (_query.isEmpty ||
                          m.name.toLowerCase().contains(_query) ||
                          m.region.toLowerCase().contains(_query)))
                  .toList();
              if (filtered.isEmpty) {
                return Center(child: Text(s.t('no_results'), style: const TextStyle(color: AppColors.muted)));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final map = filtered[i];
                  final firstOfRegion = i == 0 || filtered[i - 1].region != map.region;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (firstOfRegion) ...[
                        if (i > 0) const SizedBox(height: 16),
                        Text(map.region, style: display(16, color: AppColors.gold)),
                        const SizedBox(height: 8),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.line),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => MapDetailScreen(map: map)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(map.name,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                  ),
                                  if (map.maxLevel > 0)
                                    Text('${map.minLevel}-${map.maxLevel}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right, color: Color(0xFF6E6859)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class MapDetailScreen extends ConsumerWidget {
  const MapDetailScreen({super.key, required this.map});

  final GameMap map;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final pois = ref.watch(mapDetailProvider(map.id));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(map.name, style: display(20)),
        actions: [
          IconButton(
            tooltip: s.t('wiki'),
            onPressed: () => openWikiPage(context, ref, map.name),
            icon: const Icon(Icons.menu_book_outlined, color: AppColors.gold),
          ),
        ],
      ),
      body: AsyncView<List<PointOfInterest>>(
        value: pois,
        onRetry: () => ref.invalidate(mapDetailProvider(map.id)),
        builder: (list) {
          final waypoints = list.where((p) => p.isWaypoint && p.name.isNotEmpty).toList();
          final others = list.where((p) => !p.isWaypoint && p.name.isNotEmpty).toList();
          if (waypoints.isEmpty && others.isEmpty) {
            return Center(child: Text(s.t('nothing_here'), style: const TextStyle(color: AppColors.muted)));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(s.t('waypoint_note'), style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
              const SizedBox(height: 14),
              if (waypoints.isNotEmpty) ...[
                SectionHeader(title: s.t('waypoints'), trailing: '${waypoints.length}'),
                const SizedBox(height: 10),
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    children: [for (final p in waypoints) _PoiRow(poi: p)],
                  ),
                ),
              ],
              if (others.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionHeader(title: s.t('landmarks'), trailing: '${others.length}'),
                const SizedBox(height: 10),
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    children: [for (final p in others) _PoiRow(poi: p)],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PoiRow extends ConsumerWidget {
  const _PoiRow({required this.poi});

  final PointOfInterest poi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            poi.isWaypoint ? Icons.place : Icons.flag_outlined,
            size: 18,
            color: poi.isWaypoint ? AppColors.gold : AppColors.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(poi.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          if (poi.chatLink.isNotEmpty)
            IconButton(
              tooltip: s.t('copy'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: poi.chatLink));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('copied'))));
              },
              icon: const Icon(Icons.copy, size: 18, color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}
