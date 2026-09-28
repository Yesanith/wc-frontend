import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'account.dart';
import 'api.dart';

/// every item material storage can hold, stocked or not. the storage lists
/// its empty slots too, so this is the set of things a deposit would take
final materialSlotIdsProvider = FutureProvider<Set<int>>((ref) async {
  final rows = await accountApi(ref).materials();
  return {for (final r in rows) asInt(r['id'])};
});

/// places a stack can be tidied from. gear being worn, the armory and the
/// material storage itself are left alone
bool _loose(OwnedPlace p) => p.kind == OwnedKind.bank || p.kind == OwnedKind.shared || p.kind == OwnedKind.bags;

/// item kinds that never stack, a sword in two bags is two swords
const _unstackable = {'Weapon', 'Armor', 'Trinket', 'Back', 'Bag', 'Tool', 'Relic', 'JadeTechModule', 'PowerCore'};

class CleanupRow {
  const CleanupRow(this.itemId, this.count, this.places);

  final int itemId;

  /// how many of the item the row is about
  final int count;

  /// the stacks it is spread over, loose ones only
  final Map<OwnedPlace, int> places;
}

class CleanupReport {
  const CleanupReport({
    required this.deposit,
    required this.split,
    required this.junk,
    required this.junkValue,
    required this.full,
    required this.storageCap,
  });

  /// materials sitting in bags or the bank that storage would take
  final List<CleanupRow> deposit;

  /// the same stackable item in more than one bag or storage
  final List<CleanupRow> split;

  /// junk to sell to a vendor, and what it all fetches
  final List<CleanupRow> junk;
  final int junkValue;

  /// materials whose storage slot looks full
  final List<CleanupRow> full;

  /// the guessed size of one material slot, 0 when unknown
  final int storageCap;

  bool get isEmpty => deposit.isEmpty && split.isEmpty && junk.isEmpty && full.isEmpty;
}

/// the api does not say how big material slots are. every slot holds the
/// same, 250 more per storage expander, so the fullest slot rounded up to
/// the next 250 is the best guess there is
int guessStorageCap(Iterable<int> materialCounts) {
  var top = 0;
  for (final c in materialCounts) {
    if (c > top) top = c;
  }
  if (top <= 0) return 0;
  return ((top + 249) ~/ 250) * 250;
}

CleanupReport buildCleanup({
  required Map<int, Map<OwnedPlace, int>> owned,
  required Map<int, Json> items,
  required Set<int> materialIds,
}) {
  final deposit = <CleanupRow>[];
  final split = <CleanupRow>[];
  final junk = <CleanupRow>[];
  var junkValue = 0;
  final stored = <int, int>{};

  for (final entry in owned.entries) {
    final id = entry.key;
    final loose = {
      for (final p in entry.value.entries)
        if (_loose(p.key)) p.key: p.value
    };
    for (final p in entry.value.entries) {
      if (p.key.kind == OwnedKind.materials) stored[id] = p.value;
    }
    if (loose.isEmpty) continue;
    final looseCount = loose.values.fold(0, (a, b) => a + b);
    final item = items[id];

    if (materialIds.contains(id)) {
      deposit.add(CleanupRow(id, looseCount, loose));
    } else if (loose.length > 1 && !_unstackable.contains(item?['type'])) {
      split.add(CleanupRow(id, looseCount, loose));
    }
    if (item?['rarity'] == 'Junk') {
      junk.add(CleanupRow(id, looseCount, loose));
      junkValue += asInt(item?['vendor_value']) * looseCount;
    }
  }

  final cap = guessStorageCap(stored.values);
  final full = [
    for (final e in stored.entries)
      if (cap > 0 && e.value >= cap) CleanupRow(e.key, e.value, const {})
  ];

  int byCount(CleanupRow a, CleanupRow b) => b.count.compareTo(a.count);
  deposit.sort(byCount);
  split.sort((a, b) => b.places.length != a.places.length ? b.places.length.compareTo(a.places.length) : byCount(a, b));
  junk.sort(byCount);
  full.sort(byCount);
  return CleanupReport(
    deposit: deposit,
    split: split,
    junk: junk,
    junkValue: junkValue,
    full: full,
    storageCap: cap,
  );
}

final cleanupProvider = FutureProvider<CleanupReport>((ref) async {
  final owned = await ref.watch(ownedPlacesProvider.future);
  final materialIds = await ref.watch(materialSlotIdsProvider.future);
  // rarity, type and vendor value of everything owned, cached on disk after
  // the first time
  final items = await ref.watch(gw2ApiProvider).items(owned.keys);
  return buildCleanup(owned: owned, items: items, materialIds: materialIds);
});
