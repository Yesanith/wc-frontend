import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/account.dart';
import '../state/crafting.dart';
import '../state/items.dart';
import '../state/reference.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import '../widgets/meters.dart';
import '../l10n/strings.dart';
import '../widgets/recipe_outputs.dart';
import 'trading_screen.dart';

/// everything about one item, in a sheet that slides up over the page.
/// [instance] is the equipment entry it came from, which carries the chosen
/// stats, runes, sigils and infusions
void showItemDetails(BuildContext context, int itemId, {Json? instance}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => ItemDetails(itemId: itemId, instance: instance, scroll: scroll),
    ),
  );
}

class ItemDetails extends ConsumerStatefulWidget {
  const ItemDetails({super.key, required this.itemId, this.instance, this.scroll});

  final int itemId;
  final Json? instance;
  final ScrollController? scroll;

  @override
  ConsumerState<ItemDetails> createState() => _ItemDetailsState();
}

class _ItemDetailsState extends ConsumerState<ItemDetails> {
  /// the prices are shown for this many, the steps players buy in
  int _qty = 1;

  int get itemId => widget.itemId;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final item = ref.watch(itemProvider(itemId)).valueOrNull;
    final instance = widget.instance;

    final upgradeIds = intList(instance?['upgrades']);
    final infusionIds = intList(instance?['infusions']);
    final details = item?['details'] is Map ? Map<String, dynamic>.from(item!['details'] as Map) : null;
    final attributes = _attributes(instance, details);
    final name = (item?['name'] as String?) ?? s.t('item_n', {'id': itemId});
    final rarity = item?['rarity'] as String?;
    final description = '${item?['description'] ?? ''}'.replaceAll(RegExp(r'<[^>]*>'), '');
    final chatLink = '${item?['chat_link'] ?? ''}';
    final watching = ref.watch(watchlistProvider).contains(itemId);
    final subtitle = [
      if (rarity != null) rarity,
      if (details?['type'] != null) '${details?['type']}' else if (item?['type'] != null) '${item?['type']}',
      if (asInt(item?['level']) > 0) s.t('level_n', {'n': asInt(item?['level'])}),
    ].join(' · ');

    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Row(
          children: [
            ItemIcon(url: item?['icon'] as String?, rarity: rarity, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: display(21, color: rarity == null ? AppColors.text : rarityColor(rarity))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(description, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.muted)),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ref.read(watchlistProvider.notifier).toggle(itemId),
                icon: Icon(watching ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                label: Text(watching ? s.t('unwatch') : s.t('watch')),
              ),
            ),
            if (chatLink.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: s.t('copy_chat_link'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: chatLink));
                  showToast(context, '${s.t('copied')} $chatLink');
                },
                icon: const Icon(Icons.link_rounded),
              ),
            ],
          ],
        ),
        if (attributes.isNotEmpty) ...[
          Eyebrow(s.t('attributes'), trailing: _comboLabel(_comboName(ref, instance, details))),
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
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.gold)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (upgradeIds.isNotEmpty) ...[
          Eyebrow(s.t('upgrades')),
          for (final id in upgradeIds) _UpgradeRow(itemId: id),
        ],
        if (infusionIds.isNotEmpty) ...[
          Eyebrow(s.t('infusions')),
          for (final id in infusionIds) _UpgradeRow(itemId: id),
        ],
        _OwnedSection(itemId: itemId),
        const SizedBox(height: 8),
        _PricePanel(item: item, itemId: itemId, qty: _qty, onQty: (q) => setState(() => _qty = q)),
        _UsedInSection(itemId: itemId, itemName: name),
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
      ],
    );
  }

  Widget? _comboLabel(String? combo) => combo == null
      ? null
      : Text(combo, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13));
}

/// the trading post keeps 5% as a listing fee and 10% when it sells
int afterTradingFees(int price) => price - (price * 0.05).ceil() - (price * 0.10).ceil();

String placeLabel(S s, OwnedPlace p) => switch (p.kind) {
      OwnedKind.bank => s.t('bank'),
      OwnedKind.materials => s.t('materials'),
      OwnedKind.shared => s.t('shared_slots'),
      OwnedKind.armory => s.t('armory'),
      OwnedKind.bags => p.character ?? '',
      OwnedKind.equipped => s.t('equipped_on', {'name': p.character ?? ''}),
    };

IconData placeIcon(OwnedKind kind) => switch (kind) {
      OwnedKind.bank => Icons.account_balance_outlined,
      OwnedKind.materials => Icons.category_outlined,
      OwnedKind.shared => Icons.all_inbox_outlined,
      OwnedKind.armory => Icons.shield_moon_outlined,
      OwnedKind.bags => Icons.backpack_outlined,
      OwnedKind.equipped => Icons.checkroom_outlined,
    };

/// how many the account has, and where each stack is
class _OwnedSection extends ConsumerWidget {
  const _OwnedSection({required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final places = ref.watch(ownedPlacesProvider).valueOrNull?[itemId];
    final total = places?.values.fold(0, (a, b) => a + b) ?? ref.watch(accountTotalsProvider).valueOrNull?[itemId] ?? 0;
    if (total == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Eyebrow(s.t('n_owned', {'n': fmtInt(total)})),
        if (places != null)
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (final e in places.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Icon(placeIcon(e.key.kind), size: 18, color: AppColors.muted),
                        const SizedBox(width: 12),
                        Expanded(child: Text(placeLabel(s, e.key), style: const TextStyle(fontSize: 14))),
                        Text('×${fmtInt(e.value)}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// buy order and sell listing for the chosen quantity, and what flipping earns
class _PricePanel extends ConsumerWidget {
  const _PricePanel({required this.item, required this.itemId, required this.qty, required this.onQty});

  final Json? item;
  final int itemId;
  final int qty;
  final ValueChanged<int> onQty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final priced = ref.watch(priceProvider(itemId));
    // "not sold" only once the trading post has actually answered
    if (!priced.hasValue) return const SizedBox.shrink();
    final price = priced.value;
    final buys = price?['buys'];
    final sells = price?['sells'];
    final buy = buys is Map ? asInt(buys['unit_price']) : 0;
    final sell = sells is Map ? asInt(sells['unit_price']) : 0;
    final vendor = asInt(item?['vendor_value']);

    final stepper = Row(
      children: [
        Expanded(child: Kicker(s.t('quantity').toUpperCase(), color: AppColors.hint)),
        IconButton(
          // 1, 10 and 250 are the steps people trade in
          onPressed: qty > 1 ? () => onQty(qty == 250 ? 10 : (qty == 10 ? 1 : qty - 1)) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 44,
          child: Text('$qty',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        IconButton(
          onPressed: qty < 250 ? () => onQty(qty == 1 ? 10 : (qty == 10 ? 250 : qty + 1)) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );

    if (buy == 0 && sell == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('not_tradable'), style: const TextStyle(fontSize: 14, color: AppColors.muted)),
            if (vendor > 0) ...[
              const SizedBox(height: 8),
              stepper,
              Row(
                children: [
                  Expanded(child: Text(s.t('vendor_value'), style: const TextStyle(fontSize: 14))),
                  CoinDots(vendor * qty),
                ],
              ),
            ],
          ],
        ),
      );
    }

    Widget side(String label, int unit, int count, String countLabel, Color accent) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
                const SizedBox(height: 6),
                CoinDots(unit * qty, size: 16, weight: FontWeight.w800),
                const SizedBox(height: 6),
                Text('$countLabel ${compact(count)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        );

    // buy at the highest order, relist a copper under the lowest listing
    final flip = buy > 0 && sell > 0 ? afterTradingFees(sell - 1) - buy : 0;
    final margin = buy > 0 ? flip / buy : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stepper,
        const SizedBox(height: 4),
        Row(
          children: [
            side(s.t('highest_buy'), buy, buys is Map ? asInt(buys['quantity']) : 0, s.t('demand'), AppColors.blue),
            const SizedBox(width: 8),
            side(s.t('lowest_sell'), sell, sells is Map ? asInt(sells['quantity']) : 0, s.t('supply'), AppColors.gold),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.t('flip_profit'), style: const TextStyle(fontSize: 14)),
                  Text('${(margin * 100).round()}%', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            CoinDots(flip * qty, color: flip >= 0 ? AppColors.green : AppColors.red),
          ],
        ),
      ],
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
        onTap: () => showItemDetails(context, itemId),
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

/// the name of the stat combination, from the equipped piece or the item
String? _comboName(WidgetRef ref, Json? instance, Json? details) {
  final chosen = instance?['stats'];
  final infix = details?['infix_upgrade'];
  final id = chosen is Map ? asInt(chosen['id']) : (infix is Map ? asInt(infix['id']) : 0);
  if (id <= 0) return null;
  return ref.watch(itemStatsProvider).valueOrNull?[id];
}

/// what this item is an ingredient of. a few rows here, the rest a tap away
class _UsedInSection extends ConsumerWidget {
  const _UsedInSection({required this.itemId, required this.itemName});

  final int itemId;
  final String itemName;

  static const _preview = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final rows = ref.watch(usedInProvider(itemId)).valueOrNull;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    final preview = rows.take(_preview).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: s.t('used_in'), trailing: fmtInt(rows.length)),
          const SizedBox(height: 10),
          for (var i = 0; i < preview.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RecipeOutputRow(entry: preview[i], chunkKey: chunkKeyFor(preview, i)),
            ),
          if (rows.length > _preview)
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RecipeOutputsScreen(title: s.t('used_in_item', {'item': itemName}), entries: rows),
                ),
              ),
              child: Text(s.t('show_all_n', {'n': fmtInt(rows.length)})),
            ),
        ],
      ),
    );
  }
}
