import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'api.dart';
import 'characters.dart';
import 'reference.dart';

/// one profession with its specializations and weapons
class ProfessionInfo {
  const ProfessionInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.iconBig,
    required this.specializations,
    required this.weapons,
  });

  /// the api id, "Guardian", which is also what characters carry
  final String id;

  /// the name in the app's language
  final String name;
  final String? icon;
  final String? iconBig;

  /// core lines first, then the elite ones, each in the order the api lists them
  final List<Json> specializations;

  /// weapon name -> the api entry, with flags and the elite line it needs
  final Map<String, Json> weapons;

  Json? specialization(int id) {
    for (final spec in specializations) {
      if (asInt(spec['id']) == id) return spec;
    }
    return null;
  }
}

/// every profession, keyed by its api id. the list and the lines come from
/// the monthly disk cache, so this costs a network trip once
final professionsProvider = FutureProvider<Map<String, ProfessionInfo>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final rows = await referenceRows(ref, 'professions', '/professions');
  final specIds = <int>{
    for (final r in rows) ...intList(r['specializations']),
  };
  final specs = await api.specializations(specIds);

  final out = <String, ProfessionInfo>{};
  for (final r in rows) {
    final id = '${r['id']}';
    final lines = [
      for (final specId in intList(r['specializations']))
        if (specs[specId] != null) specs[specId]!,
    ];
    // a stable sort keeps the api order inside each group
    final core = lines.where((l) => l['elite'] != true).toList();
    final elite = lines.where((l) => l['elite'] == true).toList();
    out[id] = ProfessionInfo(
      id: id,
      name: '${r['name'] ?? id}',
      icon: r['icon'] as String?,
      iconBig: r['icon_big'] as String?,
      specializations: [...core, ...elite],
      weapons: {
        if (r['weapons'] is Map)
          for (final e in (r['weapons'] as Map).entries)
            if (e.value is Map) '${e.key}': Map<String, dynamic>.from(e.value as Map),
      },
    );
  }
  return out;
});

/// the professions in the order the character select screen uses
const professionOrder = [
  'Guardian',
  'Revenant',
  'Warrior',
  'Engineer',
  'Ranger',
  'Thief',
  'Elementalist',
  'Mesmer',
  'Necromancer',
];

/// the elite line a character plays right now, from its active build
Json? activeElite(Json character, ProfessionInfo? profession) {
  if (profession == null) return null;
  final build = activeBuild(character);
  for (final spec in (build?['specializations'] as List?) ?? const []) {
    if (spec is! Map) continue;
    final line = profession.specialization(asInt(spec['id']));
    if (line != null && line['elite'] == true) return line;
  }
  return null;
}

/// the class icon to show for a character: the elite line's own icon when
/// one is slotted, the profession's otherwise
String? classIcon(Json character, ProfessionInfo? profession, {bool big = false}) {
  final elite = activeElite(character, profession);
  final eliteIcon = elite?[big ? 'profession_icon_big' : 'profession_icon'] as String?;
  if (eliteIcon != null && eliteIcon.isNotEmpty) return eliteIcon;
  return big ? (profession?.iconBig ?? profession?.icon) : (profession?.icon ?? profession?.iconBig);
}
