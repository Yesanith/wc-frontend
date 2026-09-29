import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/community.dart';
import '../state/guild_events.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'guild_events_screen.dart' show eventFailureText;

/// a guild's tyria companion members with their roles. the leader appoints
/// officers here, who may then create and manage events
class GuildRosterScreen extends ConsumerStatefulWidget {
  const GuildRosterScreen({super.key, required this.guild});

  final MyGuild guild;

  @override
  ConsumerState<GuildRosterScreen> createState() => _GuildRosterScreenState();
}

class _GuildRosterScreenState extends ConsumerState<GuildRosterScreen> {
  String? _busyFor;

  Future<void> _setRole(RosterMember m, String role) async {
    final s = ref.read(stringsProvider);
    setState(() => _busyFor = m.userId);
    try {
      await setGuildRole(widget.guild.id, m.userId, role);
      ref.invalidate(guildRosterProvider(widget.guild.id));
      if (mounted) {
        showToast(
          context,
          s.t(role == 'officer' ? 'roster_made_officer' : 'roster_made_member', {'name': m.accountName}),
        );
      }
    } catch (e) {
      if (mounted) showToast(context, eventFailureText(s, e));
    } finally {
      if (mounted) setState(() => _busyFor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final me = ref.watch(sessionProvider).valueOrNull?.user.id;
    final g = widget.guild;
    final leading = g.role == 'leader';

    return Scaffold(
      appBar: AppBar(title: Text(g.tag.isEmpty ? g.name : '${g.name} [${g.tag}]')),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          ref.invalidate(guildRosterProvider(g.id));
          await ref.read(guildRosterProvider(g.id).future);
        },
        child: AsyncView<List<RosterMember>>(
          value: ref.watch(guildRosterProvider(g.id)),
          onRetry: () => ref.invalidate(guildRosterProvider(g.id)),
          builder: (members) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                leading ? s.t('roster_note_leader') : s.t('roster_note'),
                style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    for (final m in members)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              m.role == 'leader'
                                  ? Icons.workspace_premium
                                  : m.role == 'officer'
                                      ? Icons.military_tech_outlined
                                      : Icons.person_outline,
                              size: 20,
                              color: m.role == 'member' ? AppColors.muted : AppColors.gold,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.accountName,
                                    style: TextStyle(fontWeight: m.userId == me ? FontWeight.w800 : FontWeight.w600),
                                  ),
                                  Text(s.t('guild_role_${m.role}'),
                                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                ],
                              ),
                            ),
                            if (leading && m.role != 'leader' && m.userId != me)
                              _busyFor == m.userId
                                  ? const SizedBox(
                                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : TextButton(
                                      onPressed: _busyFor != null
                                          ? null
                                          : () => _setRole(m, m.role == 'officer' ? 'member' : 'officer'),
                                      child: Text(
                                        m.role == 'officer' ? s.t('roster_make_member') : s.t('roster_make_officer'),
                                      ),
                                    ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(s.t('roster_missing'), style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.hint)),
            ],
          ),
        ),
      ),
    );
  }
}
