typedef Json = Map<String, dynamic>;

int asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

/// 1284567 -> 1.284.567
String fmtInt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return (n < 0 ? '-' : '') + b.toString();
}

String fmtHours(dynamic seconds) => '${fmtInt(asInt(seconds) ~/ 3600)} sa';

String compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
  if (n >= 10000) return '${(n / 1000).toStringAsFixed(1).replaceAll('.', ',')} B';
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
