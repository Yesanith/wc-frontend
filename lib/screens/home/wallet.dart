part of '../home_screen.dart';

class _Wallet extends ConsumerWidget {
  const _Wallet();

  /// karma, laurels, gems, astral acclaim and spirit shards
  static const _highlights = [2, 3, 4, 63, 23];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<List<WalletEntry>>(
      value: ref.watch(walletProvider),
      onRetry: () => ref.invalidate(walletProvider),
      builder: (w) {
        final byId = {for (final e in w) e.id: e};
        return Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: () => ref.read(sectionProvider.notifier).state = AppSection.account,
              child: GlowCard(
                glow: AppColors.amber,
                child: Row(
                  children: [
                    Expanded(child: CoinDots(byId[1]?.value ?? 0, size: 22, weight: FontWeight.w800)),
                    if (byId[1] != null)
                      Text(byId[1]!.name, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            GridView(
              // three across on a phone, more where there is room, never a tile wider than a phone's
              gridDelegate: const AdaptiveGridDelegate(
                minColumns: 3,
                maxTile: 150,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.25,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final id in _highlights)
                  if (byId[id] != null) _CurrencyTile(byId[id]!),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile(this.entry);

  final WalletEntry entry;

  @override
  Widget build(BuildContext context) {
    final icon = entry.icon;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox.square(dimension: 22, child: icon == null ? null : CachedIcon(url: icon)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(compact(entry.value),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFeatures: _tabular)),
              Text(entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}
