import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community.dart';

/// a Blish HUD module the player linked to their account, which the app can cut
class ModuleLink {
  const ModuleLink({required this.id, required this.label, required this.createdAt, this.lastUsedAt});

  final String id;
  final String label;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
}

/// the links as the server lists them. what is not a link is left out
List<ModuleLink> parseModuleLinks(dynamic raw) {
  if (raw is! List) return const [];
  final out = <ModuleLink>[];
  for (final row in raw) {
    if (row is! Map) continue;
    final id = '${row['id'] ?? ''}';
    final created = DateTime.tryParse('${row['created_at']}');
    if (id.isEmpty || created == null) continue;
    final used = row['last_used_at'] == null ? null : DateTime.tryParse('${row['last_used_at']}');
    final label = '${row['label'] ?? ''}'.trim();
    out.add(ModuleLink(
      id: id,
      label: label.isEmpty ? 'Blish HUD' : label,
      createdAt: created.toLocal(),
      lastUsedAt: used?.toLocal(),
    ));
  }
  return out;
}

/// a code to type into the module: eight characters in two groups, good for ten minutes and for one use
class ModuleLinkCode {
  const ModuleLinkCode(this.code, this.expiresAt);

  final String code;
  final DateTime expiresAt;
}

ModuleLinkCode? parseModuleLinkCode(dynamic raw) {
  if (raw is! Map) return null;
  final code = '${raw['code'] ?? ''}';
  final expires = DateTime.tryParse('${raw['expires_at']}');
  if (code.isEmpty || expires == null) return null;
  return ModuleLinkCode(code, expires.toLocal());
}

/// asks the server for a code. throws when the server would not give one
Future<ModuleLinkCode> createModuleLinkCode() async {
  final raw = await Supabase.instance.client.rpc('create_module_link_code');
  final code = parseModuleLinkCode(raw);
  if (code == null) throw StateError('not a code');
  return code;
}

/// cuts one link: the module is refused from its next call
Future<void> revokeModuleLink(String id) => Supabase.instance.client.rpc('revoke_module_link', params: {'p_id': id});

/// the modules linked to the signed in player
final myModuleLinksProvider = FutureProvider.autoDispose<List<ModuleLink>>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return const [];
  return parseModuleLinks(await Supabase.instance.client.rpc('my_module_links'));
});
