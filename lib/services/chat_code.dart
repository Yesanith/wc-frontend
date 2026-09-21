import 'dart:convert';
import 'dart:typed_data';

import '../util.dart';

/// profession order used by build template chat codes
const _professionIds = <String, int>{
  'Guardian': 1,
  'Warrior': 2,
  'Engineer': 3,
  'Ranger': 4,
  'Thief': 5,
  'Elementalist': 6,
  'Mesmer': 7,
  'Necromancer': 8,
  'Revenant': 9,
};

/// Builds the `[&...]` chat link for a build template.
///
/// The format packs the three specialization lines with two bits per trait
/// tier, then the land and water skills as palette ids, then a small block
/// of profession specific data. Skills are stored as palette ids, which only
/// the profession endpoint knows, so [profession] has to be the response of
/// /v2/professions/<name>.
String? buildChatCode(Json build, Json? profession, Map<int, Json> specDetails) {
  final professionName = '${build['profession'] ?? ''}';
  final professionId = _professionIds[professionName];
  if (professionId == null || profession == null) return null;

  // skill id -> palette id
  final palette = <int, int>{};
  for (final pair in (profession['skills_by_palette'] as List?) ?? const []) {
    if (pair is List && pair.length >= 2) {
      palette[asInt(pair[1])] = asInt(pair[0]);
    }
  }
  if (palette.isEmpty) return null;

  final bytes = Uint8List(44);
  bytes[0] = 0x0D;
  bytes[1] = professionId;

  final specs = ((build['specializations'] as List?) ?? const []).whereType<Map>().toList();
  for (var i = 0; i < 3; i++) {
    if (i >= specs.length) continue;
    final spec = Map<String, dynamic>.from(specs[i]);
    final specId = asInt(spec['id']);
    bytes[2 + i * 2] = specId & 0xFF;

    // two bits per tier: 0 none, 1 top, 2 middle, 3 bottom
    final chosen = ((spec['traits'] as List?) ?? const []).toList();
    final majors = intListOf(specDetails[specId]?['major_traits']);
    var packed = 0;
    for (var tier = 0; tier < 3 && tier < chosen.length; tier++) {
      final traitId = asInt(chosen[tier]);
      var position = 0;
      if (traitId > 0 && majors.length >= (tier + 1) * 3) {
        for (var slot = 0; slot < 3; slot++) {
          if (majors[tier * 3 + slot] == traitId) position = slot + 1;
        }
      }
      packed |= position << (tier * 2);
    }
    bytes[3 + i * 2] = packed;
  }

  int paletteOf(dynamic skillId) => palette[asInt(skillId)] ?? 0;

  final land = build['skills'] is Map ? build['skills'] as Map : const {};
  final water = build['aquatic_skills'] is Map ? build['aquatic_skills'] as Map : const {};
  final landUtilities = ((land['utilities'] as List?) ?? const []).toList();
  final waterUtilities = ((water['utilities'] as List?) ?? const []).toList();

  final slots = <List<dynamic>>[
    [land['heal'], water['heal']],
    [_at(landUtilities, 0), _at(waterUtilities, 0)],
    [_at(landUtilities, 1), _at(waterUtilities, 1)],
    [_at(landUtilities, 2), _at(waterUtilities, 2)],
    [land['elite'], water['elite']],
  ];
  var offset = 8;
  for (final slot in slots) {
    final landPalette = paletteOf(slot[0]);
    final waterPalette = paletteOf(slot[1]);
    bytes[offset] = landPalette & 0xFF;
    bytes[offset + 1] = (landPalette >> 8) & 0xFF;
    bytes[offset + 2] = waterPalette & 0xFF;
    bytes[offset + 3] = (waterPalette >> 8) & 0xFF;
    offset += 4;
  }

  // profession block: ranger pets and revenant legends, everything else stays zero
  if (professionName == 'Ranger') {
    final terrestrial = _petList(build, 'terrestrial');
    final aquatic = _petList(build, 'aquatic');
    bytes[28] = _at(terrestrial, 0) ?? 0;
    bytes[29] = _at(terrestrial, 1) ?? 0;
    bytes[30] = _at(aquatic, 0) ?? 0;
    bytes[31] = _at(aquatic, 1) ?? 0;
  } else if (professionName == 'Revenant') {
    final legends = [
      for (final l in (build['legends'] as List?) ?? const [])
        int.tryParse('$l'.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
    ];
    bytes[28] = _at(legends, 0) ?? 0;
    bytes[29] = _at(legends, 1) ?? 0;
    bytes[30] = _at(legends, 2) ?? 0;
    bytes[31] = _at(legends, 3) ?? 0;
  }

  return '[&${base64Encode(bytes)}]';
}

/// null safe list access, avoids relying on newer core extensions
T? _at<T>(List<T> list, int index) => index >= 0 && index < list.length ? list[index] : null;

List<int> intListOf(dynamic raw) => [
      for (final v in (raw as List?) ?? const [])
        if (v != null) asInt(v),
    ];

List<int> _petList(Json build, String key) {
  final pets = build['pets'];
  if (pets is Map) return intListOf(pets[key]);
  if (pets is List && key == 'terrestrial') return intListOf(pets);
  return const [];
}
