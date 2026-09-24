import 'dart:async';

typedef Json = Map<String, dynamic>;

int asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

/// thousands separator, set by the app root when the language changes
String groupSeparator = ',';

/// 1284567 -> 1,284,567 (or 1.284.567 etc. depending on the language)
String fmtInt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(groupSeparator);
    b.write(s[i]);
  }
  return (n < 0 ? '-' : '') + b.toString();
}

String fmtHours(dynamic seconds, [String unit = 'h']) => '${fmtInt(asInt(seconds) ~/ 3600)} $unit';

String compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}k';
  return fmtInt(n);
}

class Coins {
  Coins(int copper)
      : gold = copper ~/ 10000,
        silver = (copper % 10000) ~/ 100,
        copper = copper % 100;
  final int gold;
  final int silver;
  final int copper;
}

class WalletEntry {
  const WalletEntry(this.id, this.value, this.name, this.icon, this.order);
  final int id;
  final int value;
  final String name;
  final String? icon;
  final int order;
}

class ItemSlot {
  const ItemSlot(this.id, this.count, this.item);
  final int id;
  final int count;
  final Json? item;
  String get name => (item?['name'] as String?) ?? 'Item #$id';
  String? get icon => item?['icon'] as String?;
  String? get rarity => item?['rarity'] as String?;
  String? get type => item?['type'] as String?;
}

// words that stay lowercase inside a name, unless they start it
const _minorWords = {'of', 'the', 'and', 'in', 'to', 'a', 'an'};

/// api ids like "stronghold_of_the_faithful" or "thief" have no display
/// name in the api, so build one: "Stronghold of the Faithful"
String titleCase(String raw) {
  final words = raw.replaceAll('_', ' ').split(' ').where((w) => w.isNotEmpty).toList();
  return [
    for (var i = 0; i < words.length; i++)
      if (i > 0 && _minorWords.contains(words[i].toLowerCase()))
        words[i].toLowerCase()
      else
        words[i][0].toUpperCase() + words[i].substring(1).toLowerCase(),
  ].join(' ');
}

// the api uses its own attribute keys, the game shows different names
const _attributeNames = {
  'CritDamage': 'Ferocity',
  'ConditionDamage': 'Condition Damage',
  'ConditionDuration': 'Expertise',
  'BoonDuration': 'Concentration',
  'Healing': 'Healing Power',
  'HealingPower': 'Healing Power',
  'AgonyResistance': 'Agony Resistance',
};

List<int> intList(dynamic raw) => [
      for (final v in (raw as List?) ?? const [])
        if (v != null) asInt(v),
    ];

// the item table and /v2/professions spell three weapons differently, so an
// equipped longbow never lines up with the profession's skill list unless the
// name is translated first
const _weaponKeys = {
  'LongBow': 'Longbow',
  'ShortBow': 'Shortbow',
  'Harpoon': 'Spear',
};

/// an item's details.type as the profession endpoint keys its weapon skills
String professionWeaponKey(String itemType) => _weaponKeys[itemType] ?? itemType;

String attributeName(String raw) {
  final mapped = _attributeNames[raw];
  if (mapped != null) return mapped;
  // split the remaining camel case keys: MagicFind -> Magic Find
  return raw.replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (m) => ' ${m[1]}');
}

/// runs at most [size] async tasks at the same time, the rest wait their turn
class TaskPool {
  TaskPool(this.size);

  final int size;
  int _running = 0;
  final List<Completer<void>> _waiting = [];

  Future<T> run<T>(Future<T> Function() task) async {
    if (_running >= size) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    _running++;
    try {
      return await task();
    } finally {
      _running--;
      if (_waiting.isNotEmpty) _waiting.removeAt(0).complete();
    }
  }
}
