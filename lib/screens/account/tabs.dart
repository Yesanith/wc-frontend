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
            const SizedBox(height: 12),
            const _WealthPanel(),
            const SizedBox(height: 14),
            // on the site the currencies are short rows in columns, three where there is room
            if (SiteScope.of(context))
              LayoutBuilder(builder: (context, box) {
                final columns = box.maxWidth >= 840 ? 3 : (box.maxWidth >= 520 ? 2 : 1);
                final width = (box.maxWidth - (columns - 1) * 24) / columns;
                return Wrap(
                  spacing: 24,
                  children: [
                    for (final e in others)
                      Container(
                        width: width,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.track))),
                        child: Row(
                          children: [
                            SizedBox.square(
                              dimension: 22,
                              child: e.icon == null
                                  ? Icon(Icons.circle_outlined, size: 16, color: AppColors.muted)
                                  : CachedIcon(url: e.icon!, fit: BoxFit.contain),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(e.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14))),
                            Text(fmtInt(e.value), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                );
              })
            else
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

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const _StorageSearch(kind: 'bank'),
            const SizedBox(height: 12),
            if (slots.any((x) => x?.binding != null)) ...[
              Row(
                children: [
                  Icon(Icons.lock, size: 13, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(s.t('bound_soul'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(width: 14),
                  Icon(Icons.person, size: 13, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(s.t('bound_account'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
                query.isEmpty
                    ? s.t('slots_used', {'a': used, 'b': slots.length})
                    : found == 0
                        ? s.t('no_results')
                        : s.t('n_found', {'n': found}),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold)),
            const SizedBox(height: 12),
            if (site)
              Wrap(
                spacing: 32,
                runSpacing: 20,
                children: [for (final t in tabs) SizedBox(width: 10 * 46 + 9 * 5, child: tab(t))],
              )
            else
              for (final t in tabs) Padding(padding: const EdgeInsets.only(bottom: 16), child: tab(t)),
          ],
        );
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
        // on the site the builds are the rows of a list, not cards
        final site = SiteScope.of(context);
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
