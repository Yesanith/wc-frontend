part of '../guild_events_screen.dart';

class _RsvpBar extends ConsumerWidget {
  const _RsvpBar({
    required this.mine,
    required this.busy,
    required this.onAnswer,
    this.onChangeAccount,
    this.discordOnly = false,
  });

  final EventParticipant? mine;
  final bool busy;
  final ValueChanged<String> onAnswer;

  /// signed up for in Discord, only not going can be answered here
  final bool discordOnly;

  /// null unless the player has several accounts to choose from
  final VoidCallback? onChangeAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final current = mine?.status;
    Widget button(String status, IconData icon) {
      // waiting counts as having said going
      final selected = current == status || (status == 'going' && current == 'waitlist');
      final blocked = busy || (discordOnly && status != 'declined');
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: selected
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: statusColor(current)),
                  onPressed: blocked ? null : () => onAnswer(status),
                  icon: Icon(icon, size: 18),
                  label: Text(s.t(current == 'waitlist' ? 'rsvp_waitlist' : 'rsvp_$status')),
                )
              : OutlinedButton.icon(
                  onPressed: blocked ? null : () => onAnswer(status),
                  icon: Icon(icon, size: 18),
                  label: Text(s.t('rsvp_$status')),
                ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (discordOnly)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 16, color: AppColors.gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.t('event_discord_only'),
                    style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSoft),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            button('going', Icons.check),
            button('maybe', Icons.help_outline),
            button('declined', Icons.close),
          ],
        ),
        if (mine?.role != null && (current == 'going' || current == 'waitlist'))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${s.t('event_your_role')}: ${s.t('role_${mine!.role}')}${mine!.profession == null ? '' : ' · ${mine!.profession}'}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        if (onChangeAccount != null && mine != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  s.t('event_signed_up_as', {'name': mine!.name}),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              TextButton(
                onPressed: busy ? null : onChangeAccount,
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: Text(s.t('event_change_account'), style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
      ],
    );
  }
}

/// the roles the player could also play, for whoever puts the group together
class _FlexChips extends ConsumerWidget {
  const _FlexChips({required this.roles, required this.mine, required this.busy, required this.onToggle});

  final Iterable<String> roles;
  final EventParticipant mine;
  final bool busy;
  final void Function(String role, bool on) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final others = [
      for (final r in roles)
        if (r != mine.role) r,
    ];
    if (others.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('event_flex'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in others)
                FilterChip(
                  label: Text(s.t('role_$r')),
                  selected: mine.flex.contains(r),
                  onSelected: busy ? null : (on) => onToggle(r, on),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends ConsumerWidget {
  const _Group({
    required this.title,
    required this.people,
    required this.showRole,
    required this.me,
    this.numbered = false,
  });

  final String title;
  final List<EventParticipant> people;
  final bool showRole;
  final String? me;
  final bool numbered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (people.isEmpty) return const SizedBox.shrink();
    final professions = ref.watch(professionsProvider).valueOrNull ?? const <String, ProfessionInfo>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Eyebrow(title),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < people.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      if (numbered)
                        SizedBox(
                          width: 22,
                          child: Text('${i + 1}.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        ),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.surface2,
                        foregroundImage: people[i].avatarUrl == null ? null : NetworkImage(people[i].avatarUrl!),
                        child: Icon(Icons.person_outline, size: 16, color: AppColors.muted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          people[i].name,
                          style: TextStyle(fontWeight: people[i].userId == me ? FontWeight.w800 : FontWeight.w500),
                        ),
                      ),
                      if (people[i].profession != null) ...[
                        ProfessionIcon(url: professions[people[i].profession]?.icon, size: 18),
                        const SizedBox(width: 4),
                        Text(professions[people[i].profession]?.name ?? people[i].profession!,
                            style: TextStyle(fontSize: 12, color: AppColors.textSoft)),
                        const SizedBox(width: 8),
                      ],
                      if (showRole && people[i].role != null)
                        Text(s.t('role_${people[i].role}'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      if (showRole && people[i].flex.isNotEmpty)
                        Flexible(
                          child: Text(
                            ' +${people[i].flex.map((r) => s.t('role_$r')).join('/')}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: AppColors.gold),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
