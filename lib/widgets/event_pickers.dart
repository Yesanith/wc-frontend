import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/guild_events.dart' show eventProfessions;
import '../state/professions.dart';
import '../theme.dart';
import 'class_icon.dart';

/// a role of an event with its places and how many are going as it
typedef RolePlaces = ({String role, int slots, int taken});

/// asks which role a player comes as. a role that is full cannot be picked, unless the player has it already
Future<String?> pickEventRole(BuildContext context, S s, List<RolePlaces> roles, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(s.t('event_pick_role'), style: display(18)),
          ),
          for (final r in roles)
            ListTile(
              enabled: r.taken < r.slots || r.role == current,
              title: Text(s.t('role_${r.role}')),
              subtitle: r.taken >= r.slots && r.role != current ? Text(s.t('oe_role_full')) : null,
              trailing: Text(
                '${r.taken}/${r.slots}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: r.taken >= r.slots ? AppColors.muted : AppColors.gold,
                ),
              ),
              onTap: () => Navigator.of(ctx).pop(r.role),
            ),
        ],
      ),
    ),
  );
}

/// asks which profession a player comes as in a role
Future<String?> pickEventProfession(BuildContext context, S s, String role) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final professions = ref.watch(professionsProvider).valueOrNull ?? const <String, ProfessionInfo>{};
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(s.t('event_pick_profession', {'role': s.t('role_$role')}), style: display(18)),
              ),
              for (final p in eventProfessions)
                ListTile(
                  leading: ProfessionIcon(url: professions[p]?.icon, size: 28),
                  title: Text(professions[p]?.name ?? p),
                  onTap: () => Navigator.of(ctx).pop(p),
                ),
            ],
          ),
        );
      },
    ),
  );
}
