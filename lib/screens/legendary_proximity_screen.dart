import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/legendary_proximity.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import 'crafting_screen.dart';

/// the legendaries the account is closest to: what their materials still cost, how much of them it has, and what the trading post
/// does not sell that is still missing. a tap opens the recipe tree
class LegendaryProximityScreen extends ConsumerWidget {
  const LegendaryProximityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      appBar: AppBar(surfaceTintColor: Colors.transparent, title: Text(s.t('legendary_closest'))),
      body: AsyncView<List<LegendaryDistance>>(
        value: ref.watch(legendaryProximityProvider),
        permission: 'inventories',
        onRetry: () => ref.invalidate(legendaryProximityProvider),
        builder: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(s.t('legendary_closest_note'), style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted)),
            const SizedBox(height: 12),
            if (list.isEmpty) EmptyNote(s.t('legendary_closest_none')),
            for (final (i, d) in list.take(40).indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () => openPanel(context, (_) => CraftingDetailScreen(itemId: d.itemId)),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
                      ),
                      ItemIcon(url: d.item?['icon'] as String?, rarity: 'Legendary', size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${d.item?['name'] ?? '#${d.itemId}'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w800, color: rarityColor('Legendary'))),
                            const SizedBox(height: 6),
                            Bar(value: d.progress),
                            const SizedBox(height: 4),
                            Text(
                              [
                                s.t('legendary_have_pct', {'n': (d.progress * 100).round()}),
                                if (d.unpricedMissing > 0) s.t('legendary_unpriced', {'n': d.unpricedMissing}),
                              ].join(' · '),
                              style: TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          CoinText(d.missingCost, size: 13.5),
                          Text(s.t('legendary_to_buy'), style: TextStyle(fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
