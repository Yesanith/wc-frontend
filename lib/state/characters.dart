import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'api.dart';

final charactersProvider = FutureProvider<List<Json>>((ref) async {
  final api = accountApi(ref);
  final list = await api.characters();
  list.sort((a, b) => '${b['last_modified'] ?? ''}'.compareTo('${a['last_modified'] ?? ''}'));
  return list;
});

Json? characterByName(List<Json> chars, String name) {
  for (final c in chars) {
    if (c['name'] == name) return c;
  }
  return null;
}

/// stored equipment templates of a character
List<Json> equipmentTabs(Json c) => [
      for (final t in (c['equipment_tabs'] as List?) ?? const [])
        if (t is Map) Map<String, dynamic>.from(t),
    ];

/// equipment of one template, or of the active one when [tab] is null
List<Json> equipmentForTab(Json c, int? tab) {
  final eq = (c['equipment'] as List?) ?? const [];
  final wanted = tab ?? c['active_equipment_tab'];
  return [
    for (final e in eq)
      if (e is Map &&
          (wanted == null || e['tabs'] is! List || (e['tabs'] as List).contains(wanted)))
        Map<String, dynamic>.from(e),
  ];
}

List<Json> activeEquipment(Json c) => equipmentForTab(c, null);

List<Json?> bagSlots(Json c) {
  final out = <Json?>[];
  for (final bag in (c['bags'] as List?) ?? const []) {
    if (bag is! Map) continue;
    for (final s in (bag['inventory'] as List?) ?? const []) {
      out.add(s is Map ? Map<String, dynamic>.from(s) : null);
    }
  }
  return out;
}

Json? activeBuild(Json c) {
  for (final t in (c['build_tabs'] as List?) ?? const []) {
    if (t is Map && t['is_active'] == true && t['build'] is Map) {
      return Map<String, dynamic>.from(t['build'] as Map);
    }
  }
  return null;
}

final characterItemsProvider = FutureProvider.family<Map<int, Json>, String>((ref, name) async {
  final api = accountApi(ref);
  final chars = await ref.watch(charactersProvider.future);
  final c = characterByName(chars, name);
  if (c == null) return <int, Json>{};
  final ids = <int>{
    for (final e in activeEquipment(c)) asInt(e['id']),
    for (final s in bagSlots(c))
      if (s != null) asInt(s['id']),
  };
  return api.items(ids);
});
