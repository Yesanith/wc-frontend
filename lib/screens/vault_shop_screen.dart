import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/account.dart';
import '../state/settings.dart';
import '../state/vault.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'item_sheet.dart';

/// astral acclaim is a wallet currency
const _astralAcclaim = 63;

/// the wizard's vault reward shop: season, balance and every listing
class VaultShopScreen extends ConsumerWidget {
  const VaultShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final season = ref.watch(vaultSeasonProvider).valueOrNull;
    final listings = ref.watch(vaultListingsProvider);
    var balance = 0;
    for (final e in ref.watch(walletProvider).valueOrNull ?? const <WalletEntry>[]) {
      if (e.id == _astralAcclaim) balance = e.value;
    }
    final end = DateTime.tryParse('${season?['end'] ?? ''}')?.toLocal();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('vault_shop'), style: display(20)),
      ),
      body: AsyncView<List<VaultListing>>(
        value: listings,
        permission: 'progression',
        onRetry: () => ref.invalidate(vaultListingsProvider),
        builder: (rows) {
          final items = <Widget>[];
          String? lastType;
          for (final row in rows) {
            if (row.type != lastType) {
              lastType = row.type;
              items.add(Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: SectionHeader(title: s.t('vault_type_${row.type.toLowerCase()}')),
              ));
            }
            items.add(_ListingRow(row: row, balance: balance));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (season != null) Text('${season['title'] ?? ''}', style: display(17)),
                    if (end != null)
                      Text(s.t('season_ends', {'d': '${end.day}.${end.month}.${end.year}'}),
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(s.t('astral_acclaim'),
                              style: const TextStyle(fontSize: 14, color: AppColors.textSoft)),
                        ),
                        Text(fmtInt(balance),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.gold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...items,
            ],
          );
        },
      ),
    );
  }
}

class _ListingRow extends ConsumerWidget {
  const _ListingRow({required this.row, required this.balance});

  final VaultListing row;
  final int balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: row.soldOut ? 0.45 : 1,
        child: ItemRow(
          icon: row.item?['icon'] as String?,
          rarity: row.item?['rarity'] as String?,
          title: row.count > 1 ? '${row.count} x ${row.name}' : row.name,
          subtitle: row.limit > 0 ? s.t('bought_of', {'n': row.purchased, 'm': row.limit}) : null,
          trailing: Text(fmtInt(row.cost),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: row.cost <= balance ? AppColors.gold : AppColors.muted,
              )),
          onTap: () => showItemSheet(
            context,
            id: row.itemId,
            name: row.name,
            icon: row.item?['icon'] as String?,
            rarity: row.item?['rarity'] as String?,
            type: row.item?['type'] as String?,
            count: row.count,
          ),
        ),
      ),
    );
  }
}
