part of '../account_screen.dart';

class _WalletTab extends ConsumerWidget {
  const _WalletTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final wallet = ref.watch(walletProvider);
    return AsyncView<List<WalletEntry>>(
      value: wallet,
      onRetry: () => ref.invalidate(walletProvider),
      builder: (list) {
        var copper = 0;
        for (final e in list) {
          if (e.id == 1) copper = e.value;
        }
        final coins = Coins(copper);
        final others = list.where((e) => e.id != 1).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // the gold is the first thing, on a site the table of currencies comes next and the account's own panels after it
            ...[
              if (SiteScope.of(context)) ...[
                // the gold is one of the currencies of the table, under the gems
                // the account's own figures are in the corner of the heading
                _WalletSite(entries: list),
              ] else ...[
                TwoColumnRows(
                  gap: 20,
                  breakpoint: 820,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Color.lerp(AppColors.surface, AppColors.gold, 0.07),
                        borderRadius: BorderRadius.circular(AppRadius.window),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Kicker(s.t('gold').caps),
                          const SizedBox(height: 6),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.end,
                            spacing: 12,
                            children: [
                              _coin(fmtInt(coins.gold), 'g', AppColors.coinGold, 34),
                              _coin('${coins.silver}', 's', AppColors.silver, 20),
                              _coin('${coins.copper}', 'c', AppColors.copper, 20),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _AccountProfile(),
                    const SizedBox(height: 12),
                    const _AccountCounters(),
                    const _WealthPanel(),
                  ],
                ),
              ],
            ],
            if (!SiteScope.of(context)) ...[
              const SizedBox(height: 14),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Column(
                  children: [
                    for (var i = 0; i < others.length; i++)
                      Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: i == others.length - 1 ? Colors.transparent : AppColors.track),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: others[i].icon == null
                                  ? Icon(Icons.circle_outlined, size: 20, color: AppColors.muted)
                                  : CachedIcon(url: others[i].icon!, fit: BoxFit.contain),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(others[i].name,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            ),
                            Text(fmtInt(others[i].value),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _coin(String value, String unit, Color color, double size) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: value, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800)),
          TextSpan(text: ' $unit', style: TextStyle(fontSize: size * 0.55, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

/// the tab of the bank that is looked at on a site: null is all of them
final _bankTabProvider = StateProvider<int?>((ref) => null);

class _BankTab extends ConsumerWidget {
  const _BankTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final bank = ref.watch(bankProvider);
    return AsyncView<List<ItemSlot?>>(
      value: bank,
      onRetry: () => ref.invalidate(bankProvider),
      builder: (slots) {
        final used = slots.where((s) => s != null).length;
        final query = ref.watch(_storageQueryProvider('bank')).trim().toLowerCase();
        bool hit(ItemSlot? slot) => slot != null && slot.name.toLowerCase().contains(query);
        final found = query.isEmpty ? 0 : slots.where(hit).length;
        Widget slotOf(ItemSlot? slot) {
          // while searching, what is not looked for fades, so the bank keeps its places as the game's does
          final dim = query.isNotEmpty && !hit(slot);
          final Widget icon;
          if (slot == null) {
            icon = const ItemIcon(empty: true);
          } else {
            icon = GestureDetector(
              onTap: () => showItemSheet(
                context,
                id: slot.id,
                name: slot.name,
                icon: slot.icon,
                rarity: slot.rarity,
                type: slot.type,
                count: slot.count,
                binding: slot.binding,
                boundTo: slot.boundTo,
              ),
              child: ItemIcon(url: slot.icon, rarity: slot.rarity, count: slot.count, bound: slot.binding),
            );
          }
          return dim ? Opacity(opacity: 0.15, child: IgnorePointer(child: icon)) : icon;
        }

        // the bank by its tabs of thirty, as in the game: ten to a row on the site, as many as fit on a phone
        const perTab = 30;
        final site = SiteScope.of(context);
        final tabs = [
          for (var t = 0; t * perTab < slots.length; t++)
            // a tab with nothing looked for in it is left out while searching
            if (query.isEmpty || slots.skip(t * perTab).take(perTab).any(hit)) t,
        ];
        Widget tab(int t) {
          final range = [for (var i = t * perTab; i < (t + 1) * perTab && i < slots.length; i++) i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('bank_tab_n', {'n': t + 1}),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
              const SizedBox(height: 6),
              if (site)
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [for (final i in range) SizedBox.square(dimension: 46, child: slotOf(slots[i]))],
                )
              else
                GridView(
                  gridDelegate:
                      const AdaptiveGridDelegate(minColumns: 8, maxTile: 60, mainAxisSpacing: 6, crossAxisSpacing: 6),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [for (final i in range) slotOf(slots[i])],
                ),
            ],
          );
        }

        final chosen = ref.watch(_bankTabProvider);
        final one = site && chosen != null && chosen < (slots.length / perTab).ceil() ? chosen : null;

        Widget legend() => Row(
              children: [
                if (slots.any((x) => x?.binding != null)) ...[
                  Icon(Icons.lock, size: 13, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(s.t('bound_soul'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(width: 14),
                  Icon(Icons.person, size: 13, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(s.t('bound_account'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ],
            );
        final count = Text(
            query.isEmpty
                ? s.t('slots_used', {'a': used, 'b': slots.length})
                : found == 0
                    ? s.t('no_results')
                    : s.t('n_found', {'n': found}),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold));

        if (!site) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const _StorageSearch(kind: 'bank'),
              const SizedBox(height: 12),
              if (slots.any((x) => x?.binding != null)) ...[legend(), const SizedBox(height: 8)],
              count,
              const SizedBox(height: 12),
              for (final t in tabs) Padding(padding: const EdgeInsets.only(bottom: 16), child: tab(t)),
            ],
          );
        }

        // a site has the tabs down the side, as the game has them, and the slots of the one that is chosen, or of all, beside them
        Widget tabButton(String label, String fill, bool selected, VoidCallback onTap) => InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: selected ? AppColors.text : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: selected ? AppColors.bg : AppColors.textSoft)),
                    ),
                    Text(fill,
                        style: TextStyle(
                            fontSize: 12, color: selected ? AppColors.bg.withValues(alpha: 0.75) : AppColors.muted)),
                  ],
                ),
              ),
            );
        final tabCount = (slots.length / perTab).ceil();
        final side = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tabButton(s.t('all'), '$used/${slots.length}', one == null,
                () => ref.read(_bankTabProvider.notifier).state = null),
            for (var t = 0; t < tabCount; t++)
              tabButton(
                s.t('bank_tab_n', {'n': t + 1}),
                '${slots.skip(t * perTab).take(perTab).where((x) => x != null).length}/${slots.skip(t * perTab).take(perTab).length}',
                one == t,
                () => ref.read(_bankTabProvider.notifier).state = t,
              ),
          ],
        );
        Widget bigSlot(int i) => SizedBox.square(dimension: 56, child: slotOf(slots[i]));
        final body = one != null
            ? Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (var i = one * perTab; i < (one + 1) * perTab && i < slots.length; i++) bigSlot(i)],
              )
            : Wrap(
                spacing: 32,
                runSpacing: 20,
                children: [for (final t in tabs) SizedBox(width: 10 * 46 + 9 * 5, child: tab(t))],
              );
        return LayoutBuilder(builder: (context, box) {
          final narrow = box.maxWidth < 900;
          final main = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StorageSearch(kind: 'bank'),
              const SizedBox(height: 12),
              Row(children: [count, const Spacer(), legend()]),
              const SizedBox(height: 14),
              body,
            ],
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              if (narrow) ...[side, const SizedBox(height: 16), main] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [SizedBox(width: 220, child: side), const SizedBox(width: 24), Expanded(child: main)],
                ),
            ],
          );
        });
      },
    );
  }
}

class _MaterialsTab extends ConsumerWidget {
  const _MaterialsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final groups = ref.watch(materialGroupsProvider);
    return AsyncView<List<MaterialGroup>>(
      value: groups,
      onRetry: () => ref.invalidate(materialGroupsProvider),
      builder: (list) {
        if (list.isEmpty) return _EmptyTab(s.t('materials_empty'));
        // a site has the materials as a table with what each is worth
        if (SiteScope.of(context)) {
          return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [_MaterialsSite(groups: list)]);
        }
        // one grid per storage category, like the game shows it. a tap on a
        // category's title folds it away, and the choice is remembered
        final query = ref.watch(_storageQueryProvider('materials')).trim().toLowerCase();
        // while searching only what matches, every category with some of it open
        final shown = query.isEmpty
            ? list
            : [
                for (final g in list)
                  if (g.slots.any((m) => m.name.toLowerCase().contains(query)))
                    MaterialGroup(
                        g.name,
                        [
                          for (final m in g.slots)
                            if (m.name.toLowerCase().contains(query)) m
                        ],
                        id: g.id),
              ];
        final collapsed = query.isEmpty ? ref.watch(collapsedMaterialsProvider) : const <int>{};
        final allFolded = list.every((g) => collapsed.contains(g.id));
        final found = shown.fold<int>(0, (n, g) => n + g.slots.length);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const _StorageSearch(kind: 'materials'),
            const SizedBox(height: 4),
            if (query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(found == 0 ? s.t('no_results') : s.t('n_found', {'n': found}),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold)),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => ref
                      .read(collapsedMaterialsProvider.notifier)
                      .setAll(allFolded ? <int>{} : {for (final g in list) g.id}),
                  icon: Icon(allFolded ? Icons.unfold_more : Icons.unfold_less, size: 18),
                  label: Text(s.t(allFolded ? 'expand_all' : 'collapse_all')),
                ),
              ),
            for (final g in shown) ...[
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.frame),
                onTap: query.isNotEmpty ? null : () => ref.read(collapsedMaterialsProvider.notifier).toggle(g.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child:
                            SectionHeader(title: g.name == '?' ? s.t('other') : g.name, trailing: '${g.slots.length}'),
                      ),
                      const SizedBox(width: 6),
                      Icon(collapsed.contains(g.id) ? Icons.expand_more : Icons.expand_less, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
              if (collapsed.contains(g.id))
                const SizedBox(height: 6)
              else ...[
                const SizedBox(height: 6),
                GridView(
                  gridDelegate:
                      const AdaptiveGridDelegate(minColumns: 6, maxTile: 60, mainAxisSpacing: 6, crossAxisSpacing: 6),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final m in g.slots)
                      GestureDetector(
                        onTap: () => showItemSheet(
                          context,
                          id: m.id,
                          name: m.name,
                          icon: m.icon,
                          rarity: m.rarity,
                          type: m.type,
                          count: m.count,
                          binding: m.binding,
                        ),
                        child: ItemIcon(url: m.icon, rarity: m.rarity, count: m.count, bound: m.binding),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _ArmoryTab extends ConsumerWidget {
  const _ArmoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final armory = ref.watch(armoryProvider);
    final max = ref.watch(armoryMaxProvider).valueOrNull ?? const <int, int>{};
    return AsyncView<List<ItemSlot>>(
      value: armory,
      onRetry: () => ref.invalidate(armoryProvider),
      builder: (list) {
        if (list.isEmpty) return _EmptyTab(s.t('armory_empty'));
        // a site has the armory as shelves, one for the weapons, the armor and the trinkets
        if (SiteScope.of(context)) return _ArmorySite(items: list, max: max);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final item = list[i];
            return ItemRow(
              icon: item.icon,
              rarity: item.rarity,
              title: item.name,
              // "1/2" while copies are still missing, just the count once full
              trailing: (max[item.id] ?? 0) > 1 || item.count > 1
                  ? Text(
                      (max[item.id] ?? 0) > 1 ? '${item.count}/${max[item.id]}' : 'x${item.count}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: (max[item.id] ?? 0) > item.count ? AppColors.muted : AppColors.gold,
                      ),
                    )
                  : null,
              onTap: () => showItemSheet(
                context,
                id: item.id,
                name: item.name,
                icon: item.icon,
                rarity: item.rarity,
                type: item.type,
                count: item.count,
              ),
            );
          },
        );
      },
    );
  }
}

/// the legendary armory on a site: a few totals, then a shelf for the weapons, one for the armor and one for the trinkets
class _ArmorySite extends ConsumerWidget {
  const _ArmorySite({required this.items, required this.max});

  final List<ItemSlot> items;
  final Map<int, int> max;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    String kind(ItemSlot i) => switch (i.type) {
          'Weapon' => 'weapons',
          'Armor' => 'armor',
          'Trinket' || 'Back' => 'trinkets',
          _ => 'other',
        };
    final shelves = <String, List<ItemSlot>>{};
    for (final i in items) {
      shelves.putIfAbsent(kind(i), () => []).add(i);
    }
    const order = ['weapons', 'armor', 'trinkets', 'other'];
    final label = {
      'weapons': s.t('weapons'),
      'armor': s.t('armory_armor'),
      'trinkets': s.t('armory_trinkets'),
      'other': s.t('other'),
    };
    int copies(List<ItemSlot> l) => l.fold<int>(0, (n, i) => n + i.count);

    Widget stat(String name, int n) => Padding(
          padding: const EdgeInsets.only(right: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.caps,
                  style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.muted)),
              Text(fmtInt(n), style: display(28)),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Wrap(children: [
          stat(s.t('armory_owned'), items.length),
          for (final k in order)
            if (shelves.containsKey(k)) stat(label[k]!, shelves[k]!.length),
        ]),
        for (final k in order)
          if (shelves.containsKey(k)) ...[
            const SizedBox(height: 14),
            Panel(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(child: Text(label[k]!, style: display(22))),
                      Text(s.t('armory_shelf_note', {'n': shelves[k]!.length, 'c': copies(shelves[k]!)}),
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 16,
                    children: [
                      for (final i in shelves[k]!)
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => showItemSheet(
                            context,
                            id: i.id,
                            name: i.name,
                            icon: i.icon,
                            rarity: i.rarity,
                            type: i.type,
                            count: i.count,
                          ),
                          child: SizedBox(
                            width: 96,
                            child: Column(
                              children: [
                                ItemIcon(url: i.icon, rarity: i.rarity, size: 64, count: i.count > 1 ? i.count : null),
                                const SizedBox(height: 6),
                                Text(i.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11.5, height: 1.25)),
                                if ((max[i.id] ?? 0) > i.count)
                                  Text('${i.count}/${max[i.id]}',
                                      style:
                                          TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
      ],
    );
  }
}

class _BuildsSite extends ConsumerStatefulWidget {
  const _BuildsSite({required this.builds});

  final List<Json> builds;

  @override
  ConsumerState<_BuildsSite> createState() => _BuildsSiteState();
}

class _BuildsSiteState extends ConsumerState<_BuildsSite> {
  var _selected = 0;
  var _onCharacters = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    // the build each character carries now, read from the characters
    final onCharacters = [
      for (final c in ref.watch(charactersProvider).valueOrNull ?? const <Json>[])
        if (activeBuild(c) case final b?)
          {
            ...b,
            'profession': c['profession'],
            'name': '${b['name'] ?? ''}'.trim().isEmpty ? '${c['name']}' : '${c['name']} · ${b['name']}',
          },
    ];
    final list = _onCharacters ? onCharacters : widget.builds;
    final index = _selected < list.length ? _selected : 0;
    final empty = list.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 340,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 4),
                  child: Text(s.t('builds_slots_used', {'n': widget.builds.length}),
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(spacing: 8, children: [
                    ChoiceChip(
                      label: Text(s.t('builds_stored')),
                      selected: !_onCharacters,
                      onSelected: (_) => setState(() {
                        _onCharacters = false;
                        _selected = 0;
                      }),
                    ),
                    ChoiceChip(
                      label: Text(s.t('builds_on_characters')),
                      selected: _onCharacters,
                      onSelected: (_) => setState(() {
                        _onCharacters = true;
                        _selected = 0;
                      }),
                    ),
                  ]),
                ),
                for (var i = 0; i < list.length; i++)
                  Builder(builder: (context) {
                    final build = list[i];
                    final profession = '${build['profession'] ?? ''}';
                    final name = '${build['name'] ?? ''}'.trim();
                    final specs = ((build['specializations'] as List?) ?? const []).whereType<Map>().length;
                    final on = i == index;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: on ? AppColors.surface : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          side: BorderSide(color: on ? AppColors.gold : AppColors.line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => setState(() => _selected = i),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 5,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: professionColor(profession),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name.isEmpty ? s.t('unnamed_build') : name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                                      Text('$profession · ${s.t('n_specializations', {'n': specs})}',
                                          style: TextStyle(fontSize: 12, color: professionColor(profession))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Panel(
              padding: EdgeInsets.zero,
              child: empty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(child: Text(s.t('no_build'), style: TextStyle(color: AppColors.muted))),
                    )
                  : BuildView(
                      key: ValueKey('$_onCharacters$index'),
                      buildData: list[index],
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// saved build templates from the account wide build storage
class _BuildsTab extends ConsumerWidget {
  const _BuildsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final builds = ref.watch(buildStorageProvider);
    return AsyncView<List<Json>>(
      value: builds,
      onRetry: () => ref.invalidate(buildStorageProvider),
      builder: (list) {
        if (list.isEmpty) return _EmptyTab(s.t('builds_empty'));
        // on the site the list stands at the left and the chosen build is shown whole beside it
        final site = SiteScope.of(context);
        if (site) return _BuildsSite(builds: list);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => SizedBox(height: site ? 0 : 8),
          itemBuilder: (context, i) {
            final build = list[i];
            final profession = '${build['profession'] ?? ''}';
            final name = '${build['name'] ?? ''}'.trim();
            final specs = ((build['specializations'] as List?) ?? const []).whereType<Map>().length;
            return Material(
              color: site ? Colors.transparent : AppColors.surface,
              shape: site
                  ? Border(bottom: BorderSide(color: AppColors.track))
                  : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      side: BorderSide(color: AppColors.line),
                    ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => BuildDetailScreen(buildData: build)),
                ),
                child: Padding(
                  padding: site ? const EdgeInsets.symmetric(horizontal: 4, vertical: 9) : const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: site ? 4 : 8,
                        height: site ? 32 : 40,
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
                            Text(name.isEmpty ? s.t('unnamed_build') : name,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                            Text('$profession · ${s.t('n_specializations', {'n': specs})}',
                                style: TextStyle(fontSize: 12, color: professionColor(profession))),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.chevron),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// what is looked for in the bank and in the material storage, kept while the other tabs are open
final _storageQueryProvider = StateProvider.family<String, String>((ref, kind) => '');

/// the box to look for an item of the bank or of the material storage by its name
class _StorageSearch extends ConsumerStatefulWidget {
  const _StorageSearch({required this.kind});

  final String kind;

  @override
  ConsumerState<_StorageSearch> createState() => _StorageSearchState();
}

class _StorageSearchState extends ConsumerState<_StorageSearch> {
  late final _ctrl = TextEditingController(text: ref.read(_storageQueryProvider(widget.kind)));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _set(String value) {
    ref.read(_storageQueryProvider(widget.kind).notifier).state = value;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        // on a page a box of a box's width, not the page's
        constraints: BoxConstraints(maxWidth: SiteScope.of(context) ? 420 : double.infinity),
        child: TextField(
          controller: _ctrl,
          onChanged: _set,
          textInputAction: TextInputAction.search,
          decoration: fieldDecoration(
            s.t('search_storage'),
            prefixIcon: Icon(Icons.search, color: AppColors.gold),
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                    icon: Icon(Icons.close, color: AppColors.muted),
                    onPressed: () {
                      _ctrl.clear();
                      _set('');
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

enum _WalletSort { game, most, name }

/// the currencies on a site: all in one table of four columns, with a search, the empty ones to hide and a choice of order
class _WalletSite extends ConsumerStatefulWidget {
  const _WalletSite({required this.entries});

  final List<WalletEntry> entries;

  @override
  ConsumerState<_WalletSite> createState() => _WalletSiteState();
}

class _WalletSiteState extends ConsumerState<_WalletSite> {
  var _query = '';
  var _hideEmpty = false;
  var _sort = _WalletSort.game;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final q = _query.trim().toLowerCase();
    final list = [
      for (final e in widget.entries)
        if ((!_hideEmpty || e.value > 0) && (q.isEmpty || e.name.toLowerCase().contains(q))) e,
    ];
    switch (_sort) {
      case _WalletSort.game:
        break;
      case _WalletSort.most:
        list.sort((a, b) => b.value.compareTo(a.value));
      case _WalletSort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: s.t('wallet_search', {'n': widget.entries.length}),
                ),
              ),
            ),
            FilterChip(
              label: Text(s.t('wallet_hide_empty')),
              selected: _hideEmpty,
              onSelected: (v) => setState(() => _hideEmpty = v),
            ),
            const SizedBox(width: 8),
            for (final (sort, label) in [
              (_WalletSort.game, s.t('wallet_sort_game')),
              (_WalletSort.most, s.t('wallet_sort_most')),
              (_WalletSort.name, s.t('wallet_sort_name')),
            ])
              ChoiceChip(label: Text(label), selected: _sort == sort, onSelected: (_) => setState(() => _sort = sort)),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, box) {
          final columns = box.maxWidth >= 1000 ? 4 : (box.maxWidth >= 720 ? 3 : (box.maxWidth >= 480 ? 2 : 1));
          // in the game's order the gold sits right under the gems, which are the first
          final coin = list.indexWhere((e) => e.id == 1);
          if (_sort == _WalletSort.game && coin > 0 && list.length > columns) {
            list.insert(columns, list.removeAt(coin));
          }
          final rows = (list.length / columns).ceil();
          Widget cell(WalletEntry e, int index) {
            final lastColumn = (index + 1) % columns == 0;
            final lastRow = index ~/ columns == rows - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                border: Border(
                  right: lastColumn ? BorderSide.none : BorderSide(color: AppColors.track),
                  bottom: lastRow ? BorderSide.none : BorderSide(color: AppColors.track),
                ),
              ),
              child: Opacity(
                opacity: e.value == 0 ? 0.45 : 1,
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 22,
                      child: e.icon == null
                          ? Icon(Icons.circle_outlined, size: 16, color: AppColors.muted)
                          : CachedIcon(url: e.icon!, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(e.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                    ),
                    const SizedBox(width: 6),
                    if (e.id == 1)
                      CoinText(e.value, size: 13.5)
                    else
                      Text(fmtInt(e.value),
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()])),
                  ],
                ),
              ),
            );
          }

          return Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var r = 0; r < rows; r++)
                  Row(
                    children: [
                      for (var c = 0; c < columns; c++)
                        Expanded(
                          child: r * columns + c < list.length
                              ? cell(list[r * columns + c], r * columns + c)
                              : const SizedBox.shrink(),
                        ),
                    ],
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// what each material sells for on the trading post, by item id; an item the trading post does not take is not in it
final _materialPricesProvider = FutureProvider.autoDispose<Map<int, int>>((ref) async {
  final groups = await ref.watch(materialGroupsProvider.future);
  final ids = {
    for (final g in groups)
      for (final m in g.slots) m.id
  };
  final prices = await ref.watch(gw2ApiProvider).prices(ids);
  return {
    for (final e in prices.entries)
      if (TpPrice.fromJson(e.value).sell > 0) e.key: TpPrice.fromJson(e.value).sell,
  };
});

enum _MatSort { worth, count, name }

/// the material storage on a site: what is stored and what it is worth in four boxes, then every material in one table, with its price
/// each and the worth of the stack, a search and the category to look at
class _MaterialsSite extends ConsumerStatefulWidget {
  const _MaterialsSite({required this.groups});

  final List<MaterialGroup> groups;

  @override
  ConsumerState<_MaterialsSite> createState() => _MaterialsSiteState();
}

class _MaterialsSiteState extends ConsumerState<_MaterialsSite> {
  var _query = '';
  int? _category;
  var _sort = _MatSort.worth;

  /// some four hundred materials: shown a hundred at a time, and the search waits for a pause in the typing, so a key
  /// pressed does not build every row again
  static const _page = 100;
  var _shown = _page;
  Timer? _typing;

  @override
  void dispose() {
    _typing?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final prices = ref.watch(_materialPricesProvider).valueOrNull ?? const <int, int>{};
    final rows = [
      for (final g in widget.groups)
        for (final m in g.slots) (group: g, slot: m, unit: prices[m.id] ?? 0),
    ];
    final totalItems = rows.fold<int>(0, (n, r) => n + r.slot.count);
    final totalWorth = rows.fold<int>(0, (n, r) => n + r.unit * r.slot.count);
    final top = rows.isEmpty ? null : rows.reduce((a, b) => a.unit * a.slot.count >= b.unit * b.slot.count ? a : b);
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final r in rows)
        if ((_category == null || r.group.id == _category) && (q.isEmpty || r.slot.name.toLowerCase().contains(q))) r,
    ];
    switch (_sort) {
      case _MatSort.worth:
        shown.sort((a, b) => (b.unit * b.slot.count).compareTo(a.unit * a.slot.count));
      case _MatSort.count:
        shown.sort((a, b) => b.slot.count.compareTo(a.slot.count));
      case _MatSort.name:
        shown.sort((a, b) => a.slot.name.toLowerCase().compareTo(b.slot.name.toLowerCase()));
    }
    final maxCount = shown.isEmpty ? 1 : shown.map((r) => r.slot.count).reduce((a, b) => a > b ? a : b);

    Widget stat(String label, Widget value, String note) => Expanded(
          child: Panel(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.caps,
                    style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.muted)),
                const SizedBox(height: 4),
                value,
                const SizedBox(height: 2),
                Text(note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        );

    Widget cell(Widget child, {double? width, Alignment align = Alignment.centerRight}) =>
        SizedBox(width: width, child: Align(alignment: align, child: child));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stat(s.t('mat_stored'), Text(fmtInt(totalItems), style: display(28)),
                s.t('mat_items_kinds', {'n': rows.length})),
            const SizedBox(width: 14),
            stat(s.t('mat_worth_tp'), CoinText(totalWorth, size: 24), s.t('mat_worth_note')),
            const SizedBox(width: 14),
            stat(s.t('mat_categories'), Text('${widget.groups.length}', style: display(28)), s.t('mat_in_storage')),
            const SizedBox(width: 14),
            stat(
              s.t('mat_most_valuable'),
              Text(top?.slot.name ?? '–', maxLines: 1, overflow: TextOverflow.ellipsis, style: display(20)),
              top == null || top.unit == 0 ? '' : '${fmtInt(top.slot.count)} × ${_coinWords(top.unit)}',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                onChanged: (v) {
                  _typing?.cancel();
                  _typing = Timer(const Duration(milliseconds: 250), () {
                    if (mounted) {
                      setState(() {
                        _query = v;
                        _shown = _page;
                      });
                    }
                  });
                },
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: s.t('mat_search', {'n': rows.length}),
                ),
              ),
            ),
            ChoiceChip(
                label: Text(s.t('all')),
                selected: _category == null,
                onSelected: (_) => setState(() {
                      _category = null;
                      _shown = _page;
                    })),
            for (final g in widget.groups)
              ChoiceChip(
                label: Text(g.name),
                selected: _category == g.id,
                onSelected: (_) => setState(() {
                  _category = g.id;
                  _shown = _page;
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final (sort, label) in [
            (_MatSort.worth, s.t('mat_sort_worth')),
            (_MatSort.count, s.t('mat_sort_most')),
            (_MatSort.name, s.t('mat_sort_name')),
          ])
            ChoiceChip(label: Text(label), selected: _sort == sort, onSelected: (_) => setState(() => _sort = sort)),
        ]),
        const SizedBox(height: 12),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration:
                    BoxDecoration(color: AppColors.surface2, border: Border(bottom: BorderSide(color: AppColors.line))),
                child: Row(
                  children: [
                    Expanded(child: _hd(s.t('mat_material'), left: true)),
                    cell(const SizedBox.shrink(), width: 150),
                    cell(_hd(s.t('mat_count')), width: 90),
                    cell(_hd(s.t('mat_price_each')), width: 120),
                    cell(_hd(s.t('mat_worth')), width: 120),
                  ],
                ),
              ),
              for (final r in shown.take(_shown))
                InkWell(
                  onTap: () => showItemSheet(
                    context,
                    id: r.slot.id,
                    name: r.slot.name,
                    icon: r.slot.icon,
                    rarity: r.slot.rarity,
                    type: r.slot.type,
                    count: r.slot.count,
                    binding: r.slot.binding,
                    boundTo: r.slot.boundTo,
                  ),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.track))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              SizedBox.square(
                                dimension: 28,
                                child: r.slot.icon == null ? null : CachedIcon(url: r.slot.icon!, fit: BoxFit.contain),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(r.slot.name,
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                              ),
                              const SizedBox(width: 8),
                              Text(r.group.name, maxLines: 1, style: TextStyle(fontSize: 11.5, color: AppColors.hint)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: r.slot.count / maxCount,
                                minHeight: 7,
                                backgroundColor: AppColors.track,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                        ),
                        cell(
                            Text(fmtInt(r.slot.count),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            width: 90),
                        cell(
                            r.unit == 0
                                ? Text('–', style: TextStyle(color: AppColors.muted))
                                : CoinText(r.unit, size: 13),
                            width: 120),
                        cell(
                            r.unit == 0
                                ? Text('–', style: TextStyle(color: AppColors.muted))
                                : CoinText(r.unit * r.slot.count, size: 13),
                            width: 120),
                      ],
                    ),
                  ),
                ),
              if (shown.length > _shown)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextButton(
                    onPressed: () => setState(() => _shown += _page),
                    child: Text('${s.t('show_more')} (${shown.length - _shown})'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hd(String text, {bool left = false}) => Text(text.caps,
      textAlign: left ? TextAlign.left : TextAlign.right,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.muted));
}

/// "2s 40c" as words, for a line of text
String _coinWords(int copper) {
  final c = Coins(copper);
  return [
    if (c.gold > 0) '${fmtInt(c.gold)}g',
    if (c.silver > 0) '${c.silver}s',
    if (c.copper > 0 || copper == 0) '${c.copper}c'
  ].join(' ');
}
