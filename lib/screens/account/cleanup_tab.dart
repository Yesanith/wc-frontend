part of '../account_screen.dart';

/// what to do with what lies in the bank, the shared slots and the bags: grey items for a merchant, gear for the trading post, rare gear
/// worth more as ectoplasm, materials that belong in the material storage. what it all brings is at the top
class _CleanupTab extends ConsumerWidget {
  const _CleanupTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return AsyncView<CleanupPlan>(
      value: ref.watch(cleanupProvider),
      permission: 'inventories',
      onRetry: () => ref.invalidate(cleanupProvider),
      builder: (plan) {
        if (plan.isEmpty) {
          return ListView(padding: const EdgeInsets.all(24), children: [EmptyNote(s.t('cleanup_nothing'))]);
        }
        Widget figure(String label, Widget value) => Expanded(
              child: Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Kicker(label.caps),
                  const SizedBox(height: 6),
                  value,
                ]),
              ),
            );
        final sections = [
          (CleanupAction.junk, 'cleanup_junk', 'cleanup_junk_note', Icons.delete_outline),
          (CleanupAction.sell, 'cleanup_sell', 'cleanup_sell_note', Icons.storefront_outlined),
          (CleanupAction.salvage, 'cleanup_salvage', 'cleanup_salvage_note', Icons.handyman_outlined),
          (CleanupAction.deposit, 'cleanup_deposit', 'cleanup_deposit_note', Icons.inventory_2_outlined),
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(s.t('cleanup_intro'), style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted)),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                figure(
                    s.t('cleanup_total'),
                    CoinText(
                        plan.valueOf(CleanupAction.junk) +
                            plan.valueOf(CleanupAction.sell) +
                            plan.valueOf(CleanupAction.salvage),
                        size: 18)),
                const SizedBox(width: 10),
                figure(s.t('cleanup_ectos'), Text(plan.ectos.toStringAsFixed(1), style: display(24))),
              ]),
            ),
            for (final (action, title, note, icon) in sections)
              if (plan.of(action).isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(children: [
                  Icon(icon, size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.t(title), style: display(18))),
                  if (action != CleanupAction.deposit) CoinText(plan.valueOf(action), size: 14),
                ]),
                const SizedBox(height: 2),
                Text(s.t(note), style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 8),
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(children: [for (final e in plan.of(action).take(60)) _CleanupRow(e)]),
                ),
              ],
          ],
        );
      },
    );
  }
}

class _CleanupRow extends ConsumerWidget {
  const _CleanupRow(this.e);

  final CleanupEntry e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final slot = e.stack.slot;
    final where = switch (e.stack.where) {
      null => s.t('bank'),
      '' => s.t('shared_slots'),
      final name => name,
    };
    return InkWell(
      onTap: () => showItemSheet(context, id: slot.id, binding: slot.binding, boundTo: slot.boundTo),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          ItemIcon(url: slot.icon, rarity: slot.rarity, count: slot.count, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(slot.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: slot.rarity == null ? AppColors.text : rarityColor(slot.rarity!))),
              Text(where,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          if (e.action == CleanupAction.salvage)
            Text('≈ ${e.ectos.toStringAsFixed(1)} ecto', style: TextStyle(fontSize: 12.5, color: AppColors.textSoft))
          else if (e.value > 0)
            CoinText(e.value, size: 13),
        ]),
      ),
    );
  }
}
