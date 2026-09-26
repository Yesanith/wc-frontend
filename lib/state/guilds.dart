import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'account.dart';
import 'api.dart';
import 'reference.dart';

/// guild ids the account belongs to, plus the ones it leads
final guildIdsProvider = FutureProvider<List<String>>((ref) async {
  final account = await ref.watch(accountProvider.future);
  return [
    for (final g in (account['guilds'] as List?) ?? const []) '$g',
  ];
});

final guildProvider = FutureProvider.autoDispose.family<Json, String>((ref, id) => accountApi(ref).guild(id));

class GuildStashSlot {
  const GuildStashSlot(this.tabName, this.slots, this.coins, this.note);
  final String tabName;
  final List<ItemSlot> slots;
  final int coins;
  final String note;
}

final guildStashProvider = FutureProvider.autoDispose.family<List<GuildStashSlot>, String>((ref, id) async {
  final api = accountApi(ref);
  final tabs = await api.guildStash(id);
  final ids = <int>{};
  for (final tab in tabs) {
    for (final slot in (tab['inventory'] as List?) ?? const []) {
      if (slot is Map) ids.add(asInt(slot['id']));
    }
  }
  final items = await api.items(ids);
  return [
    for (final tab in tabs)
      GuildStashSlot(
        '${tab['note'] ?? ''}'.trim().isEmpty ? '#${tab['upgrade_id']}' : '${tab['note']}',
        [
          for (final slot in (tab['inventory'] as List?) ?? const [])
            if (slot is Map) ItemSlot(asInt(slot['id']), asInt(slot['count']), items[asInt(slot['id'])]),
        ],
        asInt(tab['coins']),
        '${tab['note'] ?? ''}',
      ),
  ];
});

class TreasuryRow {
  const TreasuryRow(this.item, this.count, this.needed);
  final Json? item;
  final int count;
  final int needed;

  String get name => (item?['name'] as String?) ?? '-';
  double get ratio => needed == 0 ? 1 : count / needed;
}

/// what the guild has stored against what its upgrades still need
final guildTreasuryProvider = FutureProvider.autoDispose.family<List<TreasuryRow>, String>((ref, id) async {
  final api = accountApi(ref);
  final rows = await api.guildTreasury(id);
  final items = await api.items(rows.map((r) => asInt(r['item_id'])));
  final out = <TreasuryRow>[];
  for (final row in rows) {
    var needed = 0;
    for (final upgrade in (row['needed_by'] as List?) ?? const []) {
      if (upgrade is Map) needed += asInt(upgrade['count']);
    }
    out.add(TreasuryRow(items[asInt(row['item_id'])], asInt(row['count']), needed));
  }
  out.sort((a, b) => a.ratio.compareTo(b.ratio));
  return out;
});

final guildLogProvider = FutureProvider.autoDispose.family<List<Json>, String>((ref, id) async {
  final log = await accountApi(ref).guildLog(id);
  log.sort((a, b) => asInt(b['id']).compareTo(asInt(a['id'])));
  return log.take(50).toList();
});

// -------------------------------------------------------------------------
// leader only parts: members, ranks, teams, storage and built upgrades

final guildMembersProvider = FutureProvider.autoDispose.family<List<Json>, String>((ref, id) async {
  final rows = await accountApi(ref).guildPart(id, 'members');
  rows.sort((a, b) => '${a['name']}'.toLowerCase().compareTo('${b['name']}'.toLowerCase()));
  return rows;
});

final guildRanksProvider = FutureProvider.autoDispose.family<List<Json>, String>((ref, id) async {
  final rows = await accountApi(ref).guildPart(id, 'ranks');
  rows.sort((a, b) => asInt(a['order']).compareTo(asInt(b['order'])));
  return rows;
});

final guildTeamsProvider =
    FutureProvider.autoDispose.family<List<Json>, String>((ref, id) => accountApi(ref).guildPart(id, 'teams'));

class GuildUpgradeRow {
  const GuildUpgradeRow(this.id, this.count, this.detail);
  final int id;
  final int count;
  final Json? detail;

  String get name => (detail?['name'] as String?) ?? '#$id';
  String? get icon => detail?['icon'] as String?;
  String get type => (detail?['type'] as String?) ?? '';
}

/// decorations and consumables in the guild hall storage
final guildStorageProvider = FutureProvider.autoDispose.family<List<GuildUpgradeRow>, String>((ref, id) async {
  final rows = await accountApi(ref).guildPart(id, 'storage');
  final catalog = await ref.watch(guildUpgradeCatalogProvider.future);
  final out = [
    for (final r in rows)
      if (asInt(r['count']) > 0) GuildUpgradeRow(asInt(r['id']), asInt(r['count']), catalog['${asInt(r['id'])}']),
  ]..sort((a, b) => a.name.compareTo(b.name));
  return out;
});

/// upgrades the guild already built, grouped later by type
final guildBuiltUpgradesProvider = FutureProvider.autoDispose.family<List<GuildUpgradeRow>, String>((ref, id) async {
  final ids = await accountApi(ref).guildUpgradeIds(id);
  final catalog = await ref.watch(guildUpgradeCatalogProvider.future);
  final out = [for (final u in ids) GuildUpgradeRow(u, 1, catalog['$u'])]
    ..sort((a, b) => a.type == b.type ? a.name.compareTo(b.name) : a.type.compareTo(b.type));
  return out;
});
