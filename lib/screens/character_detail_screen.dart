import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

const _slotLabels = <String, String>{
  'Helm': 'Kask',
  'Shoulders': 'Omuz',
  'Coat': 'Göğüs',
  'Gloves': 'Eldiven',
  'Leggings': 'Pantolon',
  'Boots': 'Bot',
  'WeaponA1': 'Silah A · Ana el',
  'WeaponA2': 'Silah A · Yan el',
  'WeaponB1': 'Silah B · Ana el',
  'WeaponB2': 'Silah B · Yan el',
  'Backpack': 'Sırt',
  'Accessory1': 'Aksesuar 1',
  'Accessory2': 'Aksesuar 2',
  'Amulet': 'Kolye',
  'Ring1': 'Yüzük 1',
  'Ring2': 'Yüzük 2',
  'Relic': 'Relic',
  'HelmAquatic': 'Su kaskı',
  'WeaponAquaticA': 'Su silahı A',
  'WeaponAquaticB': 'Su silahı B',
  'Sickle': 'Orak',
  'Axe': 'Balta',
  'Pick': 'Kazma',
};

int _slotOrder(String slot) {
  final i = _slotLabels.keys.toList().indexOf(slot);
  return i < 0 ? 999 : i;
}

class CharacterDetailScreen extends ConsumerWidget {
  const CharacterDetailScreen({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chars = ref.watch(charactersProvider);
    final list = chars.valueOrNull;
    final c = list == null ? null : characterByName(list, name);

    Widget body;
    if (c != null) {
      body = Column(
        children: [
          _Hero(c),
          const TabBar(
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.gold,
            dividerColor: AppColors.track,
            labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            tabs: [
              Tab(text: 'Ekipman'),
              Tab(text: 'Build'),
              Tab(text: 'Envanter'),
              Tab(text: 'Crafting'),
            ],
          ),
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
      body = const Center(child: Text('Karakter bulunamadı.', style: TextStyle(color: AppColors.muted)));
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
        ),
        body: body,
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero(this.c);

  final Json c;

  @override
  Widget build(BuildContext context) {
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
                    _Pill('Seviye ${asInt(c['level'])}'),
                    _Pill('${c['race'] ?? ''}'),
                    _Pill(fmtHours(c['age'])),
                    _Pill('${asInt(c['deaths'])} ölüm'),
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

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSoft)),
    );
  }
}

class _EquipmentTab extends ConsumerWidget {
  const _EquipmentTab(this.c);

  final Json c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = '${c['name']}';
    final items = ref.watch(characterItemsProvider(name));
    final eq = activeEquipment(c)
      ..sort((a, b) => _slotOrder('${a['slot']}').compareTo(_slotOrder('${b['slot']}')));

    if (eq.isEmpty) {
      return const Center(
        child: Text('Ekipman bilgisi yok.\n(characters + builds izni gerekebilir)',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
      );
    }

    return AsyncView<Map<int, Json>>(
      value: items,
      onRetry: () => ref.invalidate(characterItemsProvider(name)),
      builder: (map) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: eq.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final e = eq[i];
          final item = map[asInt(e['id'])];
          final slot = '${e['slot']}';
          final itemName = (item?['name'] as String?) ?? 'Item #${e['id']}';
          final rarity = item?['rarity'] as String?;
          return Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showItemSheet(
                context,
                name: itemName,
                icon: item?['icon'] as String?,
                rarity: rarity,
                type: item?['type'] as String?,
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    ItemIcon(url: item?['icon'] as String?, rarity: rarity, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((_slotLabels[slot] ?? slot).toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: AppColors.muted)),
                          const SizedBox(height: 2),
                          Text(itemName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          if (rarity != null)
                            Text(rarity,
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700, color: rarityColor(rarity))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BuildTab extends ConsumerWidget {
  const _BuildTab(this.c);

  final Json c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = '${c['name']}';
    final build = activeBuild(c);
    if (build == null) {
      return const Center(
        child: Text('Build bilgisi yok.\n(builds izni gerekebilir)',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
      );
    }
    final specs = ref.watch(characterSpecsProvider(name));
    final buildName = '${build['name'] ?? ''}'.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            const Text('Şablon · ', style: TextStyle(fontSize: 13, color: AppColors.muted)),
            Expanded(
              child: Text(buildName.isEmpty ? 'İsimsiz build' : buildName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AsyncView<List<Json>>(
          value: specs,
          onRetry: () => ref.invalidate(characterSpecsProvider(name)),
          builder: (list) => Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: i == list.length - 1 ? Colors.transparent : AppColors.track),
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: list[i]['icon'] is String
                                ? Image.network(
                                    list[i]['icon'] as String,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) =>
                                        const ColoredBox(color: AppColors.surface2),
                                  )
                                : const ColoredBox(color: AppColors.surface2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('${list[i]['name'] ?? ''}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                        if (list[i]['elite'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.gold),
                            ),
                            child: const Text('ELİT',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.gold)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => openWikiPage(context, '${c['profession'] ?? 'Profession'}'),
          icon: const Icon(Icons.menu_book_outlined),
          label: Text("${c['profession'] ?? 'Meslek'} wiki sayfası"),
        ),
      ],
    );
  }
}

class _InventoryTab extends ConsumerWidget {
  const _InventoryTab(this.c);

  final Json c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = '${c['name']}';
    final slots = bagSlots(c);
    if (slots.isEmpty) {
      return const Center(
        child: Text('Envanter bilgisi yok.\n(inventories izni gerekebilir)',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
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
                  const Expanded(
                    child: Text('Çantalar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
                  ),
                  Text('$used / ${slots.length} dolu',
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
                  final s = slots[i];
                  if (s == null) return const ItemIcon(empty: true);
                  final item = map[asInt(s['id'])];
                  final itemName = (item?['name'] as String?) ?? 'Item #${s['id']}';
                  return GestureDetector(
                    onTap: () => showItemSheet(
                      context,
                      name: itemName,
                      icon: item?['icon'] as String?,
                      rarity: item?['rarity'] as String?,
                      type: item?['type'] as String?,
                      count: asInt(s['count']),
                    ),
                    child: ItemIcon(
                      url: item?['icon'] as String?,
                      rarity: item?['rarity'] as String?,
                      count: asInt(s['count']),
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

class _CraftingTab extends StatelessWidget {
  const _CraftingTab(this.c);

  final Json c;

  @override
  Widget build(BuildContext context) {
    final crafting = ((c['crafting'] as List?) ?? const []).whereType<Map>().toList();
    if (crafting.isEmpty) {
      return const Center(child: Text('Crafting disiplini yok.', style: TextStyle(color: AppColors.muted)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < crafting.length; i++) _craftRow(crafting[i], i == crafting.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _craftRow(Map d, bool last) {
    final discipline = '${d['discipline'] ?? ''}';
    final rating = asInt(d['rating']);
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
              Text(active ? 'AKTİF' : 'PASİF',
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
