import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'item_detail_screen.dart';
import 'trading_screen.dart';

/// the quick actions for one item: details, wiki and the trading post.
/// lives with the screens because every action navigates to one
void showItemSheet(
  BuildContext context, {
  required int id,
  required String name,
  String? icon,
  String? rarity,
  String? type,
  int count = 1,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => Consumer(
      // keep the outer context for navigation, the sheet one is gone after pop
      builder: (_, ref, __) {
        final s = ref.watch(stringsProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ItemIcon(url: icon, rarity: rarity, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            [if (rarity != null) rarity, if (type != null) type, if (count > 1) 'x$count'].join(' · '),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: rarityColor(rarity)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(itemId: id)),
                    );
                  },
                  icon: const Icon(Icons.info_outline),
                  label: Text(s.t('item_details')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    openWikiPage(context, ref, name);
                  },
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(s.t('open_in_wiki')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => TradingItemScreen(itemId: id)),
                    );
                  },
                  icon: const Icon(Icons.storefront_outlined),
                  label: Text(s.t('trading_post')),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
