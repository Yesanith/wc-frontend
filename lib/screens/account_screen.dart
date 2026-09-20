import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(child: Text(s.t('account'), style: display(28))),
                IconButton(
                  tooltip: s.t('refresh'),
                  onPressed: () {
                    ref.invalidate(walletProvider);
                    ref.invalidate(bankProvider);
                    ref.invalidate(materialsProvider);
                  },
                  icon: const Icon(Icons.refresh, color: AppColors.gold),
                ),
              ],
            ),
          ),
          TabBar(
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.gold,
            dividerColor: AppColors.track,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            tabs: [
              Tab(text: s.t('wallet')),
              Tab(text: s.t('bank')),
              Tab(text: s.t('materials')),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _WalletTab(),
                _BankTab(),
                _MaterialsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
                color: const Color(0xFF1C1810),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF5A4A2A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(s.t('gold').toUpperCase()),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 12,
                    children: [
                      _coin(fmtInt(coins.gold), 'g', AppColors.gold, 34),
                      _coin('${coins.silver}', 's', AppColors.silver, 20),
                      _coin('${coins.copper}', 'c', AppColors.copper, 20),
                    ],
                  ),
                ],
              ),
            ),
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
                                ? const Icon(Icons.circle_outlined, size: 20, color: AppColors.muted)
                                : Image.network(
                                    others[i].icon!,
                                    errorBuilder: (context, error, stack) =>
                                        const Icon(Icons.circle_outlined, size: 20, color: AppColors.muted),
                                  ),
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
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Text(s.t('slots_used', {'a': used, 'b': slots.length}),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold)),
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
                    return GestureDetector(
                      onTap: () => showItemSheet(
                        context,
                        id: slot.id,
                        name: slot.name,
                        icon: slot.icon,
                        rarity: slot.rarity,
                        type: slot.type,
                        count: slot.count,
                      ),
                      child: ItemIcon(url: slot.icon, rarity: slot.rarity, count: slot.count),
                    );
                  },
                  childCount: slots.length,
                ),
              ),
            ),
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
    final mats = ref.watch(materialsProvider);
    return AsyncView<List<ItemSlot>>(
      value: mats,
      onRetry: () => ref.invalidate(materialsProvider),
      builder: (list) {
        if (list.isEmpty) {
          return Center(child: Text(s.t('materials_empty'), style: const TextStyle(color: AppColors.muted)));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final m = list[i];
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
                  id: m.id,
                  name: m.name,
                  icon: m.icon,
                  rarity: m.rarity,
                  type: m.type,
                  count: m.count,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      ItemIcon(url: m.icon, rarity: m.rarity, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                      Text(fmtInt(m.count),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.gold)),
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
