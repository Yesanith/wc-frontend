import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/characters.dart';
import '../state/items.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/build_view.dart';
import '../widgets/common.dart';
import 'compare_screen.dart';
import 'hero_card_screen.dart';
import 'item_detail_screen.dart';
import 'item_sheet.dart';

const _slotOrder = [
  'Helm', 'Shoulders', 'Coat', 'Gloves', 'Leggings', 'Boots', //
  'WeaponA1', 'WeaponA2', 'WeaponB1', 'WeaponB2', //
  'Backpack', 'Accessory1', 'Accessory2', 'Amulet', 'Ring1', 'Ring2', 'Relic', //
  'HelmAquatic', 'WeaponAquaticA', 'WeaponAquaticB', 'Sickle', 'Axe', 'Pick',
];

int _slotIndex(String slot) {
  final i = _slotOrder.indexOf(slot);
  return i < 0 ? 999 : i;
}

class CharacterDetailScreen extends ConsumerWidget {
  const CharacterDetailScreen({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final chars = ref.watch(charactersProvider);
    final list = chars.valueOrNull;
    final c = list == null ? null : characterByName(list, name);

    Widget body;
    if (c != null) {
      body = Column(
        children: [
          _Hero(c),
          AppTabBar(labels: [s.t('equipment'), s.t('build'), s.t('inventory'), s.t('crafting')]),
          Expanded(
            child: TabBarView(
              children: [
                _EquipmentTab(c),
                _BuildTab(c),
                _InventoryTab(c),
                _CraftingTab(c),
              ],
            ),
          ),
        ],
      );
    } else if (chars.hasError) {
      body = Padding(
        padding: const EdgeInsets.all(20),
        child: ErrorBox(message: '${chars.error}', onRetry: () => ref.invalidate(charactersProvider)),
      );
    } else if (list != null) {
      body = Center(child: Text(s.t('character_not_found'), style: const TextStyle(color: AppColors.muted)));
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          surfaceTintColor: Colors.transparent,
          title: Text(name, style: display(20)),
          actions: [
            if (c != null)
              IconButton(
                tooltip: s.t('compare'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => CompareScreen(first: name)),
                ),
                icon: const Icon(Icons.compare_arrows, color: AppColors.gold),
              ),
            if (c != null)
              IconButton(
                tooltip: s.t('hero_card'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => HeroCardScreen(name: name)),
                ),
                icon: const Icon(Icons.ios_share, color: AppColors.gold),
              ),
          ],
        ),
        body: body,
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero(this.c);

  final Json c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final prof = '${c['profession'] ?? ''}';
    final color = professionColor(prof);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(Icons.shield_outlined, color: color, size: 38),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prof, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill(s.t('level_n', {'n': asInt(c['level'])})),
                    Pill('${c['race'] ?? ''}'),
                    Pill(fmtHours(c['age'], s.t('hours_short'))),
                    Pill(s.t('deaths_n', {'n': fmtInt(asInt(c['deaths']))})),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentTab extends ConsumerStatefulWidget {
  const _EquipmentTab(this.c);

  final Json c;

  @override
  ConsumerState<_EquipmentTab> createState() => _EquipmentTabState();
}

class _EquipmentTabState extends ConsumerState<_EquipmentTab> {
  int? _tab;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final c = widget.c;
    final name = '${c['name']}';
    final items = ref.watch(characterItemsProvider(name));
    final tabs = equipmentTabs(c);
    final eq = equipmentForTab(c, _tab)
      ..sort((a, b) => _slotIndex('${a['slot']}').compareTo(_slotIndex('${b['slot']}')));

    if (eq.isEmpty && tabs.isEmpty) {
      return Center(
        child: Text(s.t('no_equipment'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
      );
    }

    return AsyncView<Map<int, Json>>(
      value: items,
      onRetry: () => ref.invalidate(characterItemsProvider(name)),
      builder: (map) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          if (tabs.length > 1) ...[
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final tab in tabs) ...[
                    ChoiceChip(
                      label: Text('${tab['name'] ?? ''}'.trim().isEmpty
                          ? s.t('template_n', {'n': asInt(tab['tab'])})
                          : '${tab['name']}'),
                      selected: (_tab ?? asInt(c['active_equipment_tab'])) == asInt(tab['tab']),
                      onSelected: (_) => setState(() => _tab = asInt(tab['tab'])),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final e in eq) ...[
            _EquipmentRow(entry: e, items: map),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _EquipmentRow extends ConsumerWidget {
  const _EquipmentRow({required this.entry, required this.items});

  final Json entry;
  final Map<int, Json> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final id = asInt(entry['id']);
    final item = items[id];
    final slot = '${entry['slot']}';
    final itemName = (item?['name'] as String?) ?? s.t('item_n', {'id': id});
    final rarity = item?['rarity'] as String?;
    final upgrades = intList(entry['upgrades']);
    final infusions = intList(entry['infusions']);
    final stats = entry['stats'];
    final statName = stats is Map && stats['attributes'] is Map
        ? (stats['attributes'] as Map).keys.take(2).map((k) => attributeName('$k')).join(', ')
        : '';

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(itemId: id, instance: entry)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ItemIcon(url: item?['icon'] as String?, rarity: rarity, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t('slot_$slot').toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text(itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    if (rarity != null || statName.isNotEmpty)
                      Text([if (rarity != null) rarity, if (statName.isNotEmpty) statName].join(' · '),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: rarityColor(rarity))),
                    if (upgrades.isNotEmpty || infusions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (final u in upgrades) ...[
                            _SmallItem(itemId: u),
                            const SizedBox(width: 4),
                          ],
                          for (final i in infusions) ...[
                            _SmallItem(itemId: i),
                            const SizedBox(width: 4),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// rune, sigil or infusion icon with its name next to it
class _SmallItem extends ConsumerWidget {
  const _SmallItem({required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(itemProvider(itemId)).valueOrNull;
    final name = (item?['name'] as String?) ?? '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ItemIcon(url: item?['icon'] as String?, rarity: item?['rarity'] as String?, size: 20),
        if (name.isNotEmpty) ...[
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          ),
        ],
      ],
    );
  }
}

class _BuildTab extends ConsumerWidget {
  const _BuildTab(this.c);

  final Json c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final build = activeBuild(c);
    if (build == null) {
      return Center(
        child: Text(s.t('no_build'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
      );
    }
    // the character endpoint leaves the profession out of the build object
    final withProfession = {'profession': c['profession'], ...build};
    final items = ref.watch(characterItemsProvider('${c['name']}')).valueOrNull ?? const <int, Json>{};
    // weapon types the character carries, so the skill bars match the gear.
    // the names go through professionWeaponKey because the item table and the
    // profession endpoint disagree on a few of them
    final weapons = <String>{};
    for (final e in activeEquipment(c)) {
      if (!'${e['slot']}'.startsWith('Weapon')) continue;
      final item = items[asInt(e['id'])];
      if (item?['type'] != 'Weapon') continue;
      final type = '${(item?['details'] as Map?)?['type'] ?? ''}';
      if (type.isNotEmpty) weapons.add(professionWeaponKey(type));
    }
    return BuildView(
      buildData: withProfession,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      weaponTypes: weapons.toList(),
    );
  }
}

class _InventoryTab extends ConsumerWidget {
  const _InventoryTab(this.c);

  final Json c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final name = '${c['name']}';
    final slots = bagSlots(c);
    if (slots.isEmpty) {
      return Center(
        child: Text(s.t('no_inventory'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
      );
    }
    final used = slots.where((s) => s != null).length;
    final items = ref.watch(characterItemsProvider(name));

    return AsyncView<Map<int, Json>>(
      value: items,
      onRetry: () => ref.invalidate(characterItemsProvider(name)),
      builder: (map) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(s.t('bags'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
                  ),
                  Text(s.t('slots_used', {'a': used, 'b': slots.length}),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final slot = slots[i];
                  if (slot == null) return const ItemIcon(empty: true);
                  final item = map[asInt(slot['id'])];
                  final itemName = (item?['name'] as String?) ?? s.t('item_n', {'id': slot['id']});
                  return GestureDetector(
                    onTap: () => showItemSheet(
                      context,
                      id: asInt(slot['id']),
                      name: itemName,
                      icon: item?['icon'] as String?,
                      rarity: item?['rarity'] as String?,
                      type: item?['type'] as String?,
                      count: asInt(slot['count']),
                    ),
                    child: ItemIcon(
                      url: item?['icon'] as String?,
                      rarity: item?['rarity'] as String?,
                      count: asInt(slot['count']),
                    ),
                  );
                },
                childCount: slots.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CraftingTab extends ConsumerWidget {
  const _CraftingTab(this.c);

  final Json c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final crafting = ((c['crafting'] as List?) ?? const []).whereType<Map>().toList();
    if (crafting.isEmpty) {
      return Center(child: Text(s.t('no_crafting'), style: const TextStyle(color: AppColors.muted)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < crafting.length; i++) _craftRow(s, crafting[i], i == crafting.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _craftRow(S s, Map d, bool last) {
    final discipline = '${d['discipline'] ?? ''}';
    final rating = asInt(d['rating']);
    // jeweler caps at 400, everything else at 500
    final max = discipline == 'Jeweler' ? 400 : 500;
    final active = d['active'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: last ? Colors.transparent : AppColors.track)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(discipline, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              Text(active ? s.t('active') : s.t('inactive'),
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: active ? AppColors.green : AppColors.hint)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Bar(value: rating / max)),
              const SizedBox(width: 10),
              Text('$rating / $max',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}
