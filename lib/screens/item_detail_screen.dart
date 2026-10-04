import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/account.dart';
import '../state/crafting.dart';
import '../state/items.dart';
import '../state/navigation.dart';
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

part 'item_detail/sections.dart';

/// everything about one item, in a sheet that slides up over the page.
/// [instance] is the equipment entry it came from, which carries the chosen
/// stats, runes, sigils and infusions
///
/// a plain item has an address of its own (/item/19721), which is in the browser while the sheet is open and is what the sheet's button copies. one that is an
/// item of a character, with its chosen stats and upgrades, is not the item and has none. [announce] is false for a link that was followed
void showItemDetails(BuildContext context, int itemId, {Json? instance, bool announce = true}) {
  final closed = instance == null
      ? linkOpened(ProviderScope.containerOf(context, listen: false), ItemLink(itemId), announce: announce)
      : null;
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
  ).whenComplete(() => closed?.call());
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
    final name = (item?['name'] as String?) ?? s.t('item_n', {'id': itemId});
    final rarity = item?['rarity'] as String?;
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
            // the address of this page, which opens the app at it
            if (instance == null) ...[
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: s.t('copy_page_link'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: linkUrl(ItemLink(itemId))));
                  showToast(context, s.t('copied'));
                },
                icon: const Icon(Icons.share_outlined),
              ),
            ],
          ],
        ),
        // description, facts, attributes and upgrade effects; vendor value
        // and recipes follow below, next to the prices
        ItemFacts(itemId: itemId, instance: instance, showVendor: false, showUsedIn: false),
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
}

/// what an item is, independent of where it is shown: description, type
/// specific facts, attributes, the bonuses of an upgrade, how it binds, its
/// vendor value and the recipes it goes into. the trading post page and the
/// item sheet both use it
class ItemFacts extends ConsumerWidget {
  const ItemFacts({
    super.key,
    required this.itemId,
    this.instance,
    this.showDescription = true,
    this.showVendor = true,
    this.showUsedIn = true,
  });

  final int itemId;

  /// the equipped piece, which carries the chosen stats
  final Json? instance;
  final bool showDescription;
  final bool showVendor;
  final bool showUsedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final item = ref.watch(itemProvider(itemId)).valueOrNull;
    if (item == null) return const SizedBox.shrink();
    final details = item['details'] is Map ? Map<String, dynamic>.from(item['details'] as Map) : null;
    final description = '${item['description'] ?? ''}'.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final attributes = _attributes(instance, details);
    final facts = itemFactRows(s, item, details);
    final flags = itemFlagLabels(s, item);
    final bonuses = [for (final b in (details?['bonuses'] as List?) ?? const []) '$b'];
    final buff = details?['infix_upgrade'] is Map && (details!['infix_upgrade'] as Map)['buff'] is Map
        ? '${((details['infix_upgrade'] as Map)['buff'] as Map)['description'] ?? ''}'
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .trim()
        : '';
    final vendor = asInt(item['vendor_value']);
    final name = (item['name'] as String?) ?? '';

    Widget row(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSoft))),
              value,
            ],
          ),
        );
    Widget valueText(String v) =>
        Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.gold));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDescription && description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(description, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.muted)),
        ],
        if (flags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final f in flags) Pill(f)]),
        ],
        if (facts.isNotEmpty || (showVendor && vendor > 0)) ...[
          Eyebrow(s.t('item_details')),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (final (label, value) in facts) row(label, valueText(value)),
                if (showVendor && vendor > 0) row(s.t('vendor_value'), CoinDots(vendor)),
              ],
            ),
          ),
        ],
        if (attributes.isNotEmpty) ...[
          Eyebrow(s.t('attributes'), trailing: _comboText(_comboName(ref, instance, details))),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (final a in attributes)
                  row(attributeName('${a['attribute']}'), valueText('+${asInt(a['modifier'])}')),
              ],
            ),
          ),
        ],
        if (bonuses.isNotEmpty || buff.isNotEmpty) ...[
          Eyebrow(s.t('upgrade_effect')),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (buff.isNotEmpty)
                  Text(buff, style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSoft)),
                for (var i = 0; i < bonuses.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('(${i + 1}) ${bonuses[i]}',
                        style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSoft)),
                  ),
              ],
            ),
          ),
        ],
        if (showUsedIn) _UsedInSection(itemId: itemId, itemName: name),
      ],
    );
  }

  Widget? _comboText(String? combo) => combo == null
      ? null
      : Text(combo, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13));
}

/// label and value pairs for what the api tells about this kind of item
List<(String, String)> itemFactRows(S s, Json item, Json? details) {
  if (details == null) return const [];
  final out = <(String, String)>[];
  final type = '${item['type'] ?? ''}';
  final minPower = asInt(details['min_power']);
  final maxPower = asInt(details['max_power']);
  if (maxPower > 0) out.add((s.t('weapon_strength'), '${fmtInt(minPower)} – ${fmtInt(maxPower)}'));
  if (details['damage_type'] != null && type == 'Weapon') out.add((s.t('damage_type'), '${details['damage_type']}'));
  if (asInt(details['defense']) > 0) out.add((s.t('defense'), fmtInt(asInt(details['defense']))));
  if (details['weight_class'] != null) out.add((s.t('weight_class'), '${details['weight_class']}'));
  final slots = (details['infusion_slots'] as List?)?.length ?? 0;
  if (slots > 0) out.add((s.t('infusion_slots'), '$slots'));
  if (type == 'Bag' && asInt(details['size']) > 0) out.add((s.t('bag_slots'), '${asInt(details['size'])}'));
  final duration = asInt(details['duration_ms']);
  if (duration > 0) out.add((s.t('duration'), _duration(duration)));
  if (asInt(details['charges']) > 0) out.add((s.t('charges'), '${asInt(details['charges'])}'));
  return out;
}

String _duration(int ms) {
  final d = Duration(milliseconds: ms);
  if (d.inHours >= 1) return d.inMinutes % 60 == 0 ? '${d.inHours} h' : '${d.inHours} h ${d.inMinutes % 60} min';
  if (d.inMinutes >= 1) {
    return d.inSeconds % 60 == 0 ? '${d.inMinutes} min' : '${d.inMinutes} min ${d.inSeconds % 60} s';
  }
  return '${d.inSeconds} s';
}

/// how the item binds and what it cannot be used for, in the app's words
List<String> itemFlagLabels(S s, Json item) {
  const shown = {
    'AccountBound': 'flag_account_bound',
    'AccountBindOnUse': 'flag_account_bind_on_use',
    'SoulbindOnAcquire': 'flag_soulbound',
    'SoulBindOnUse': 'flag_soulbind_on_use',
    'Unique': 'flag_unique',
    'NoSell': 'flag_no_sell',
    'NoSalvage': 'flag_no_salvage',
  };
  final flags = {for (final f in (item['flags'] as List?) ?? const []) '$f'};
  return [
    for (final e in shown.entries)
      if (flags.contains(e.key)) s.t(e.value),
  ];
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
