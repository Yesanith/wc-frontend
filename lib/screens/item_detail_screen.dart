import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/account.dart';
import '../state/items.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import 'goals_screen.dart';
import 'trading_screen.dart';

/// everything about one item. [instance] is the equipment entry it came from,
/// which carries the chosen stats, runes, sigils and infusions
class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId, this.instance});

  final int itemId;
  final Json? instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final item = ref.watch(itemProvider(itemId)).valueOrNull;
    final price = ref.watch(priceProvider(itemId)).valueOrNull;
    final owned = ref.watch(accountTotalsProvider).valueOrNull?[itemId] ?? 0;

    final upgradeIds = intList(instance?['upgrades']);
    final infusionIds = intList(instance?['infusions']);
    final details = item?['details'] is Map ? Map<String, dynamic>.from(item!['details'] as Map) : null;
    final attributes = _attributes(instance, details);
    final name = (item?['name'] as String?) ?? s.t('item_n', {'id': itemId});
    final description = '${item?['description'] ?? ''}'.replaceAll(RegExp(r'<[^>]*>'), '');
    final sells = price?['sells'];
    final buys = price?['buys'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('item'), style: display(20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ItemIcon(url: item?['icon'] as String?, rarity: item?['rarity'] as String?, size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (item?['rarity'] != null)
                          Pill('${item?['rarity']}', color: rarityColor(item?['rarity'] as String?)),
                        if (details?['type'] != null) Pill('${details?['type']}'),
                        if (asInt(item?['level']) > 0) Pill(s.t('level_n', {'n': asInt(item?['level'])})),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(description, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSoft)),
          ],
          if (attributes.isNotEmpty) ...[
            const SizedBox(height: 18),
            SectionHeader(title: s.t('attributes')),
            const SizedBox(height: 10),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (final a in attributes)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(attributeName('${a['attribute']}'),
                                style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
                          ),
                          Text('+${asInt(a['modifier'])}',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.gold)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (upgradeIds.isNotEmpty) ...[
            const SizedBox(height: 18),
            SectionHeader(title: s.t('upgrades')),
            const SizedBox(height: 10),
            for (final id in upgradeIds) _UpgradeRow(itemId: id),
          ],
          if (infusionIds.isNotEmpty) ...[
            const SizedBox(height: 18),
            SectionHeader(title: s.t('infusions')),
            const SizedBox(height: 10),
            for (final id in infusionIds) _UpgradeRow(itemId: id),
          ],
          const SizedBox(height: 18),
          Panel(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(s.t('you_own'), style: const TextStyle(fontSize: 14, color: AppColors.textSoft)),
                    ),
                    Text(fmtInt(owned),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.gold)),
                  ],
                ),
                if (sells is Map || buys is Map) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(s.t('lowest_sell'),
                            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                      ),
                      CoinText(sells is Map ? asInt(sells['unit_price']) : 0, size: 14),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(s.t('highest_buy'),
                            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                      ),
                      CoinText(buys is Map ? asInt(buys['unit_price']) : 0, size: 14),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => openWikiPage(context, ref, name),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: Text(s.t('wiki')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => TradingItemScreen(itemId: itemId)),
                  ),
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: Text(s.t('trading_post')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => showAddToGoalSheet(context, itemId: itemId, itemName: name),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: Text(s.t('add_to_goal')),
          ),
        ],
      ),
    );
  }
}

/// the equipped piece knows its chosen stats, otherwise fall back to the
/// fixed ones the item itself carries
List<Json> _attributes(Json? instance, Json? details) {
  final chosen = instance?['stats'];
  if (chosen is Map && chosen['attributes'] is Map) {
    final attributes = Map<String, dynamic>.from(chosen['attributes'] as Map);
    return [
      for (final e in attributes.entries) {'attribute': e.key, 'modifier': e.value},
    ];
  }
  final infix = details?['infix_upgrade'];
  if (infix is Map && infix['attributes'] is List) {
    return [
      for (final a in infix['attributes'] as List)
        if (a is Map) Map<String, dynamic>.from(a),
    ];
  }
  return const [];
}

class _UpgradeRow extends ConsumerWidget {
  const _UpgradeRow({required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final item = ref.watch(itemProvider(itemId)).valueOrNull;
    final name = (item?['name'] as String?) ?? s.t('item_n', {'id': itemId});
    final details = item?['details'] is Map ? Map<String, dynamic>.from(item!['details'] as Map) : null;
    final bonuses = [
      for (final b in (details?['bonuses'] as List?) ?? const []) '$b',
    ];
    final buff = details?['infix_upgrade'] is Map
        ? '${(details!['infix_upgrade'] as Map)['buff'] is Map ? ((details['infix_upgrade'] as Map)['buff'] as Map)['description'] ?? '' : ''}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(itemId: itemId)),
      ),
               padding: const EdgeInsets.all(10),
               child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ItemIcon(url: item?['icon'] as String?, rarity: item?['rarity'] as String?, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      if (buff.isNotEmpty)
                        Text(buff.replaceAll(RegExp(r'<[^>]*>'), ''),
                            style: const TextStyle(fontSize: 11, height: 1.35, color: AppColors.muted)),
                      for (var i = 0; i < bonuses.length; i++)
                        Text('(${i + 1}) ${bonuses[i]}',
                            style: const TextStyle(fontSize: 11, height: 1.35, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
             ),
    );
  }
}
