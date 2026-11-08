part of '../character_detail_screen.dart';

// A character as a page of the site: under the bar of the site, a way back to the list, the character on the side with the
// sections of the page under it, and the section chosen beside them. The equipment is two columns of short rows, armor on one
// side and weapons and trinkets on the other, instead of one card a row across the whole width.

/// the armor slots, which make the first column of the equipment
const _armorSlots = {'Helm', 'Shoulders', 'Coat', 'Gloves', 'Leggings', 'Boots', 'HelmAquatic'};

/// the character's page on the site. [onBack] goes back to the list
class CharacterSitePage extends ConsumerStatefulWidget {
  const CharacterSitePage({super.key, required this.name, required this.onBack});

  final String name;
  final VoidCallback onBack;

  @override
  ConsumerState<CharacterSitePage> createState() => _CharacterSitePageState();
}

class _CharacterSitePageState extends ConsumerState<CharacterSitePage> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final chars = ref.watch(charactersProvider);
    final list = chars.valueOrNull;
    final c = list == null ? null : characterByName(list, widget.name);
    final sections = [s.t('equipment'), s.t('build'), s.t('inventory'), s.t('crafting'), s.t('progress')];

    final Widget content;
    if (c != null) {
      content = switch (_section) {
        0 => _SiteEquipment(c),
        1 => _BuildTab(c),
        2 => _InventoryTab(c),
        3 => _CraftingTab(c),
        _ => CharacterProgressTab(name: '${c['name']}', profession: '${c['profession'] ?? ''}'),
      };
    } else if (chars.hasError) {
      content = ErrorBox(error: chars.error, onRetry: () => ref.invalidate(charactersProvider));
    } else if (list != null) {
      content = Center(child: Text(s.t('character_not_found'), style: TextStyle(color: AppColors.muted)));
    } else {
      content = const Center(child: CircularProgressIndicator());
    }

    // the page keeps to the width of a site, in the middle, and fills it: the way back on the left, the buttons on the right
    return LayoutBuilder(
      builder: (context, box) => Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: box.maxWidth < 1200 ? box.maxWidth : 1200,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // the way back: the list, then the character
                Row(
                  children: [
                    InkWell(
                      onTap: widget.onBack,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(s.t('nav_characters'),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gold)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('›', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    ),
                    // the name takes the room up to the buttons, which keep to the right
                    Expanded(
                      child: Text(widget.name,
                          overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: AppColors.text)),
                    ),
                    if (c != null) ...[
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => CompareScreen(first: widget.name)),
                        ),
                        icon: const Icon(Icons.compare_arrows, size: 18),
                        label: Text(s.t('compare')),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => HeroCardScreen(name: widget.name)),
                        ),
                        icon: const Icon(Icons.ios_share, size: 18),
                        label: Text(s.t('hero_card')),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 290,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (c != null) _SiteProfile(c),
                              const SizedBox(height: 14),
                              _SiteSections(
                                labels: sections,
                                selected: _section,
                                onSelect: (i) => setState(() => _section = i),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(left: 20),
                              padding: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
                              child: Text(sections[_section], style: display(24)),
                            ),
                            // the sections keep the padding they have in the app, so they line up with the heading
                            Expanded(child: content),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// the character on the side: the profession's sign, the name, and what the game says of them as a short list
class _SiteProfile extends ConsumerWidget {
  const _SiteProfile(this.c);

  final Json c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final prof = '${c['profession'] ?? ''}';
    final color = professionColor(prof);
    final info = ref.watch(professionsProvider).valueOrNull?[prof];
    final elite = activeElite(c, info)?['name'] as String?;
    final profName = info?.name ?? prof;
    final race = ref.watch(racesProvider).valueOrNull?['${c['race']}'] ?? '${c['race'] ?? ''}';

    Widget line(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.muted))),
              Expanded(
                  child: DefaultTextStyle.merge(
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), child: value)),
            ],
          ),
        );

    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClassIcon(character: c, size: 76, fallback: Icon(Icons.shield_outlined, color: color, size: 38)),
          const SizedBox(height: 12),
          Text('${c['name']}', style: display(26)),
          const SizedBox(height: 2),
          Text(elite == null ? profName : '$elite · $profName',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 14),
          line(s.t('level'), Text('${asInt(c['level'])}')),
          line(s.t('race'), Text(race)),
          line(s.t('played'), Text(fmtHours(c['age'], s.t('hours_short')))),
          line(s.t('deaths'), Text(fmtInt(asInt(c['deaths'])))),
          line(s.t('age'), BirthdayLine(created: c['created'] as String?)),
        ],
      ),
    );
  }
}

/// the sections of the character's page, as links on the side
class _SiteSections extends StatelessWidget {
  const _SiteSections({required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < labels.length; i++)
            Material(
              color: i == selected ? AppColors.gold.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelect(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Text(labels[i],
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: i == selected ? AppColors.text : AppColors.textSoft)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// the equipment as two columns of short rows: armor, then weapons and trinkets
class _SiteEquipment extends ConsumerStatefulWidget {
  const _SiteEquipment(this.c);

  final Json c;

  @override
  ConsumerState<_SiteEquipment> createState() => _SiteEquipmentState();
}

class _SiteEquipmentState extends ConsumerState<_SiteEquipment> {
  int? _tab;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final c = widget.c;
    final name = '${c['name']}';
    final tabs = equipmentTabs(c);
    final eq = equipmentForTab(c, _tab)
      ..sort((a, b) => _slotIndex('${a['slot']}').compareTo(_slotIndex('${b['slot']}')));
    if (eq.isEmpty && tabs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 0, 0),
        child: Text(s.t('no_equipment'), style: TextStyle(color: AppColors.muted)),
      );
    }
    final armor = [
      for (final e in eq)
        if (_armorSlots.contains('${e['slot']}')) e
    ];
    final rest = [
      for (final e in eq)
        if (!_armorSlots.contains('${e['slot']}')) e
    ];

    return AsyncView<Map<int, Json>>(
      value: ref.watch(characterItemsProvider(name)),
      onRetry: () => ref.invalidate(characterItemsProvider(name)),
      builder: (map) {
        Widget column(String title, List<Json> rows) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(title.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700, color: AppColors.muted)),
                ),
                for (final e in rows) _SiteEquipmentRow(entry: e, items: map),
              ],
            );
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 0, 24),
          children: [
            if (tabs.length > 1) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tab in tabs)
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${tab['name'] ?? ''}'.trim().isEmpty
                          ? s.t('template_n', {'n': asInt(tab['tab'])})
                          : '${tab['name']}'),
                      selected: (_tab ?? asInt(c['active_equipment_tab'])) == asInt(tab['tab']),
                      onSelected: (_) => setState(() => _tab = asInt(tab['tab'])),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            LayoutBuilder(
              builder: (context, box) => box.maxWidth >= 640
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: column(s.t('equipment_armor'), armor)),
                        const SizedBox(width: 32),
                        Expanded(child: column(s.t('equipment_weapons_trinkets'), rest)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        column(s.t('equipment_armor'), armor),
                        const SizedBox(height: 16),
                        column(s.t('equipment_weapons_trinkets'), rest),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// a piece of equipment as one short row: its icon, its name, and its rarity, slot and stats under it, the runes, sigils and
/// infusions as small icons at the end. a click opens it
class _SiteEquipmentRow extends ConsumerWidget {
  const _SiteEquipmentRow({required this.entry, required this.items});

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
    final stats = entry['stats'];
    final statNames = ref.watch(itemStatsProvider).valueOrNull ?? const <int, String>{};
    final comboName = stats is Map ? statNames[asInt(stats['id'])] : null;
    final extras = [...intList(entry['upgrades']), ...intList(entry['infusions'])];
    return InkWell(
      onTap: () => showItemDetails(context, id, instance: entry),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.track))),
        child: Row(
          children: [
            ItemIcon(url: item?['icon'] as String?, rarity: rarity, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text.rich(
                    TextSpan(children: [
                      if (rarity != null)
                        TextSpan(
                            text: rarity, style: TextStyle(fontWeight: FontWeight.w700, color: rarityColor(rarity))),
                      TextSpan(text: '${rarity == null ? '' : ' · '}${slotLabel(s, slot)}'),
                      if (comboName != null) TextSpan(text: ' · $comboName'),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            for (final u in extras) ...[
              const SizedBox(width: 4),
              _SiteUpgradeIcon(itemId: u),
            ],
          ],
        ),
      ),
    );
  }
}

/// a rune, sigil or infusion as a small icon, its name on hover
class _SiteUpgradeIcon extends ConsumerWidget {
  const _SiteUpgradeIcon({required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(itemProvider(itemId)).valueOrNull;
    return Tooltip(
      message: (item?['name'] as String?) ?? '',
      child: ItemIcon(url: item?['icon'] as String?, rarity: item?['rarity'] as String?, size: 20),
    );
  }
}
