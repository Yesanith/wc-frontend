part of '../guild_events_screen.dart';

// ---------------------------------------------------------------------------
// detail

class GuildEventScreen extends ConsumerStatefulWidget {
  const GuildEventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<GuildEventScreen> createState() => _GuildEventScreenState();
}

class _GuildEventScreenState extends ConsumerState<GuildEventScreen> {
  bool _busy = false;
  RealtimeChannel? _live;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _follow();
  }

  /// sign ups and edits by others arrive while the page is open. realtime
  /// sends only what row level security lets this player read
  void _follow() {
    if (!communityReady) return;
    final id = widget.eventId;
    final byEvent = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'event_id', value: id);
    final byId = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: id);
    _live = Supabase.instance.client
        .channel('event-$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_participants',
          filter: byEvent,
          callback: (_) => _changed(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'events',
          filter: byId,
          callback: (_) => _changed(),
        )
        .subscribe();
  }

  /// a burst of changes, say a promotion from the waitlist, reloads once
  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) ref.invalidate(eventDetailProvider(widget.eventId));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final live = _live;
    if (live != null) Supabase.instance.client.removeChannel(live);
    super.dispose();
  }

  Future<void> _answer(EventDetail d, String status) async {
    final s = ref.read(stringsProvider);
    String? role;
    String? profession;
    if (status == 'going' && d.roles.isNotEmpty) {
      role = await _pickRole(d);
      if (role == null) return;
      // the others see which profession fills the role
      profession = await _pickProfession(role);
      if (profession == null) return;
    }
    // then, with several accounts in the guild, which one signs up. the choice
    // made for this event before is kept, the server picks when there is one
    String? account;
    if (status != 'declined') {
      final accounts = await _accountsInGuild(d.event.guildId);
      final me = ref.read(sessionProvider).valueOrNull?.user.id;
      final mine = d.participants.where((p) => p.userId == me).firstOrNull;
      account = accountToKeep(mine?.accountId, accounts);
      if (account == null && accounts.length >= 2) {
        account = await _pickAccount(accounts);
        if (account == null) return;
      }
    }
    setState(() => _busy = true);
    try {
      final result = await rsvp(widget.eventId, status, role: role, profession: profession, accountId: account);
      if (mounted && result == 'waitlist') showToast(context, s.t('rsvp_waitlisted'));
    } catch (e) {
      if (mounted) showToast(context, eventFailureText(s, e));
    } finally {
      ref.invalidate(eventDetailProvider(widget.eventId));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _pickRole(EventDetail d) {
    final s = ref.read(stringsProvider);
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
            for (final r in d.roles.entries)
              ListTile(
                title: Text(s.t('role_${r.key}')),
                trailing: Text(
                  '${d.goingAs(r.key)}/${r.value}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: d.goingAs(r.key) >= r.value ? AppColors.muted : AppColors.gold,
                  ),
                ),
                subtitle: d.goingAs(r.key) >= r.value ? Text(s.t('event_role_full')) : null,
                onTap: () => Navigator.of(ctx).pop(r.key),
              ),
          ],
        ),
      ),
    );
  }

  /// the player's accounts in the event's guild, best first
  Future<List<GuildAccount>> _accountsInGuild(String guildId) async {
    try {
      return accountsIn(await ref.read(myGuildAccountsProvider.future), guildId);
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _pickAccount(List<GuildAccount> accounts, {String? current}) {
    final s = ref.read(stringsProvider);
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
              child: Text(s.t('event_pick_account'), style: display(18)),
            ),
            for (final a in accounts)
              ListTile(
                leading: Icon(
                  a.accountId == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: a.accountId == current ? AppColors.gold : AppColors.muted,
                ),
                title: Text(a.accountName, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(rankLabel(s, a.role, a.gw2Rank), style: TextStyle(color: AppColors.muted)),
                onTap: () => Navigator.of(ctx).pop(a.accountId),
              ),
          ],
        ),
      ),
    );
  }

  /// signs up again as the same answer, role and profession, with another account
  Future<void> _changeAccount(EventDetail d, EventParticipant mine) async {
    final s = ref.read(stringsProvider);
    final accounts = await _accountsInGuild(d.event.guildId);
    if (accounts.length < 2 || !mounted) return;
    final picked = await _pickAccount(accounts, current: accountToKeep(mine.accountId, accounts));
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      // waiting means going that did not fit, going again keeps the place in line
      await rsvp(
        widget.eventId,
        mine.status == 'maybe' ? 'maybe' : 'going',
        role: mine.role,
        profession: mine.profession,
        accountId: picked,
      );
      if (mounted) showToast(context, s.t('event_account_changed'));
    } catch (e) {
      if (mounted) showToast(context, eventFailureText(s, e));
    } finally {
      ref.invalidate(eventDetailProvider(widget.eventId));
      if (mounted) setState(() => _busy = false);
    }
  }

  /// adds or drops one role the player could also play
  Future<void> _setFlex(EventParticipant mine, String role, bool on) async {
    final s = ref.read(stringsProvider);
    final next = [
      for (final r in mine.flex)
        if (r != role) r,
      if (on) role,
    ];
    setState(() => _busy = true);
    try {
      await setFlexRoles(widget.eventId, next);
    } catch (e) {
      if (mounted) showToast(context, eventFailureText(s, e));
    } finally {
      ref.invalidate(eventDetailProvider(widget.eventId));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _pickProfession(String role) {
    final s = ref.read(stringsProvider);
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

  Future<void> _cancel() async {
    final s = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(s.t('event_cancel')),
        content: Text(s.t('event_cancel_body')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.t('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.t('event_cancel')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await cancelEvent(widget.eventId);
    } catch (e) {
      if (mounted) showToast(context, eventFailureText(s, e));
    }
    ref.invalidate(eventDetailProvider(widget.eventId));
  }

  /// null when the player backed out, otherwise whether the whole weekly
  /// series goes
  Future<bool?> _confirmDelete(GuildEvent e) {
    final s = ref.read(stringsProvider);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(s.t('event_delete')),
        content: Text(e.seriesId == null ? s.t('event_delete_body') : s.t('event_delete_weekly_body')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(s.t('cancel'))),
          if (e.seriesId != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(s.t('event_delete_series')),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(e.seriesId == null ? s.t('event_delete') : s.t('event_delete_week')),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(GuildEvent e) async {
    final s = ref.read(stringsProvider);
    final whole = await _confirmDelete(e);
    if (whole == null) return;
    setState(() => _busy = true);
    try {
      await deleteEvent(e.id, wholeSeries: whole);
      ref.invalidate(upcomingEventsProvider);
      if (mounted) {
        showToast(context, s.t('event_deleted'));
        Navigator.of(context).pop();
      }
    } catch (err) {
      if (mounted) {
        showToast(context, eventFailureText(s, err));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final detail = ref.watch(eventDetailProvider(widget.eventId));
    final me = ref.watch(sessionProvider).valueOrNull?.user.id;
    final myGuilds = ref.watch(myGuildsProvider).valueOrNull ?? const <MyGuild>[];
    // watched here, in build, so the page has the accounts by the time somebody signs up
    final myAccounts = ref.watch(myGuildAccountsProvider).valueOrNull ?? const <GuildAccount>[];

    return Scaffold(
      appBar: AppBar(title: Text(s.t('guild_events'))),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          ref.invalidate(eventDetailProvider(widget.eventId));
          await ref.read(eventDetailProvider(widget.eventId).future);
        },
        child: AsyncView<EventDetail?>(
          value: detail,
          onRetry: () => ref.invalidate(eventDetailProvider(widget.eventId)),
          builder: (d) {
            if (d == null) {
              return ListView(children: [
                const SizedBox(height: 80),
                Center(child: Text(s.t('event_gone'), style: TextStyle(color: AppColors.muted))),
              ]);
            }
            final e = d.event;
            final mine = d.participants.where((p) => p.userId == me).firstOrNull;
            final over = e.endAt.isBefore(DateTime.now());
            final open = !e.cancelled && !over;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Row(
                  children: [
                    Icon(activityIcon(e.activity), color: AppColors.gold),
                    const SizedBox(width: 8),
                    Text(s.t('activity_${e.activity}').toUpperCase(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.gold)),
                    const Spacer(),
                    if (e.seriesId != null) Pill(s.t('event_weekly')),
                  ],
                ),
                const SizedBox(height: 8),
                Text(e.title, style: display(24)),
                const SizedBox(height: 6),
                Text('${eventWhen(s, e.startAt)} – ${_clock(e.endAt)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(e.guildTag.isEmpty ? e.guildName : '${e.guildName} [${e.guildTag}]',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                if (e.organizer != null)
                  Text('${s.t('event_organizer')}: ${e.organizer}',
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                if (e.cancelled) ...[
                  const SizedBox(height: 10),
                  Pill(s.t('event_cancelled'), color: AppColors.red),
                ],
                if (e.description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(e.description, style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSoft)),
                ],
                const SizedBox(height: 18),
                if (open)
                  _RsvpBar(
                    mine: mine,
                    busy: _busy,
                    discordOnly: e.discordOnly,
                    onAnswer: (status) => _answer(d, status),
                    // only with several accounts in the guild is there anything to change,
                    // and a Discord only event is signed up for in Discord
                    onChangeAccount: !e.discordOnly &&
                            mine != null &&
                            mine.status != 'declined' &&
                            accountsIn(myAccounts, e.guildId).length >= 2
                        ? () => _changeAccount(d, mine)
                        : null,
                  ),
                if (open &&
                    mine != null &&
                    mine.role != null &&
                    (mine.status == 'going' || mine.status == 'waitlist') &&
                    d.roles.length >= 2)
                  _FlexChips(
                    roles: d.roles.keys,
                    mine: mine,
                    busy: _busy,
                    onToggle: (role, on) => _setFlex(mine, role, on),
                  ),
                if (d.roles.isNotEmpty) ...[
                  Eyebrow(s.t('event_roles')),
                  Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        for (final r in d.roles.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(s.t('role_${r.key}'))),
                                Text(
                                  '${d.goingAs(r.key)}/${r.value}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: d.goingAs(r.key) >= r.value ? AppColors.green : AppColors.gold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                _Group(
                  title: e.maxParticipants == null
                      ? '${s.t('rsvp_going')} · ${d.going}'
                      : '${s.t('rsvp_going')} · ${d.going}/${e.maxParticipants}',
                  people: d.withStatus('going'),
                  showRole: d.roles.isNotEmpty,
                  me: me,
                ),
                _Group(
                  title: '${s.t('event_waitlist')} · ${d.withStatus('waitlist').length}',
                  people: d.withStatus('waitlist'),
                  showRole: d.roles.isNotEmpty,
                  me: me,
                  numbered: true,
                ),
                _Group(
                  title: '${s.t('rsvp_maybe')} · ${d.withStatus('maybe').length}',
                  people: d.withStatus('maybe'),
                  showRole: false,
                  me: me,
                ),
                if (d.withStatus('declined').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text('${s.t('rsvp_declined')} · ${d.withStatus('declined').length}',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
                if (!e.cancelled && !over && canManageEvent(e, me, myGuilds)) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final saved = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => CreateGuildEventScreen(editing: d)),
                      );
                      if (saved == true) ref.invalidate(eventDetailProvider(widget.eventId));
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(s.t('event_edit')),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.red),
                    onPressed: _cancel,
                    icon: const Icon(Icons.event_busy_outlined),
                    label: Text(s.t('event_cancel')),
                  ),
                ],
                if (canManageEvent(e, me, myGuilds)) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                    onPressed: _busy ? null : () => _delete(e),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(s.t('event_delete')),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
