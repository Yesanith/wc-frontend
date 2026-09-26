import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'api.dart';

/// everything a build refers to: both trait rows of each specialization,
/// land and water skills, chained and toolbelt skills, pets and legends
class BuildDetail {
  const BuildDetail({
    required this.specs,
    required this.traits,
    required this.skills,
    required this.pets,
    required this.legends,
    required this.profession,
  });

  final Map<int, Json> specs;
  final Map<int, Json> traits;
  final Map<int, Json> skills;
  final Map<int, Json> pets;
  final List<Json> legends;
  final Json? profession;
}

/// pets come as a list on stored builds and as {terrestrial, aquatic} on
/// characters, so accept both shapes
List<int> petIds(Json build, String water) {
  final pets = build['pets'];
  if (pets is List) return intList(pets);
  if (pets is Map) return intList(pets[water]);
  return const [];
}

Json? skillSet(Json build, {required bool aquatic}) {
  final raw = build[aquatic ? 'aquatic_skills' : 'skills'];
  return raw is Map ? Map<String, dynamic>.from(raw) : null;
}

List<int> skillIdsOf(Json? set) {
  if (set == null) return const [];
  return [
    asInt(set['heal']),
    ...intList(set['utilities']),
    asInt(set['elite']),
  ].where((id) => id > 0).toList();
}

final buildDetailProvider = FutureProvider.autoDispose.family<BuildDetail, String>((ref, encoded) async {
  final api = accountApi(ref);
  final build = Map<String, dynamic>.from(jsonDecode(encoded) as Map);

  final specIds = <int>[];
  for (final spec in (build['specializations'] as List?) ?? const []) {
    if (spec is Map && spec['id'] != null) specIds.add(asInt(spec['id']));
  }
  final specs = await api.specializations(specIds);

  // every trait of those lines, not just the chosen ones
  final traitIds = <int>{};
  for (final spec in specs.values) {
    traitIds.addAll(intList(spec['major_traits']));
    traitIds.addAll(intList(spec['minor_traits']));
  }
  final traits = await api.traits(traitIds);

  final legendIds = [
    for (final l in (build['legends'] as List?) ?? const [])
      if (l != null) '$l',
  ];
  final legends = legendIds.isEmpty ? <Json>[] : await api.legends(legendIds);

  final skillIds = <int>{
    ...skillIdsOf(skillSet(build, aquatic: false)),
    ...skillIdsOf(skillSet(build, aquatic: true)),
  };
  for (final legend in legends) {
    skillIds.addAll([asInt(legend['swap']), asInt(legend['heal']), asInt(legend['elite'])]);
    skillIds.addAll(intList(legend['utilities']));
  }
  skillIds.removeWhere((id) => id <= 0);
  var skills = await api.skills(skillIds);

  // a second pass for toolbelt skills and chained attacks
  final extra = <int>{};
  for (final skill in skills.values) {
    final toolbelt = asInt(skill['toolbelt_skill']);
    if (toolbelt > 0) extra.add(toolbelt);
    final chain = asInt(skill['next_chain']);
    if (chain > 0) extra.add(chain);
  }
  extra.removeWhere(skills.containsKey);
  if (extra.isNotEmpty) {
    skills = {...skills, ...await api.skills(extra)};
  }

  final pets = <int>{...petIds(build, 'terrestrial'), ...petIds(build, 'aquatic')};
  final professionName = '${build['profession'] ?? ''}';
  Json? profession;
  if (professionName.isNotEmpty) {
    try {
      profession = await api.profession(professionName);
    } catch (_) {
      profession = null;
    }
  }

  return BuildDetail(
    specs: specs,
    traits: traits,
    skills: skills,
    pets: pets.isEmpty ? const {} : await api.pets(pets),
    legends: legends,
    profession: profession,
  );
});

final skillProvider = FutureProvider.autoDispose.family<Json?, int>((ref, id) async {
  final skills = await accountApi(ref).skills([id]);
  return skills[id];
});

final buildStorageProvider = FutureProvider<List<Json>>((ref) async {
  return accountApi(ref).buildStorage();
});

final armoryProvider = FutureProvider<List<ItemSlot>>((ref) async {
  final api = accountApi(ref);
  final rows = await api.legendaryArmory();
  final items = await api.items(rows.map((r) => asInt(r['id'])));
  final out = [
    for (final r in rows) ItemSlot(asInt(r['id']), asInt(r['count']), items[asInt(r['id'])]),
  ];
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
});
