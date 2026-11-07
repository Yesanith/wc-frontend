part of '../guild_events_screen.dart';

// ---------------------------------------------------------------------------
// create

class CreateGuildEventScreen extends ConsumerStatefulWidget {
  const CreateGuildEventScreen({super.key, this.editing});

  /// the event to change, null to create a new one
  final EventDetail? editing;

  @override
  ConsumerState<CreateGuildEventScreen> createState() => _CreateGuildEventScreenState();
}

class _CreateGuildEventScreenState extends ConsumerState<CreateGuildEventScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _guildId;

  /// the gw2 account the event is created with, null until chosen
  String? _accountId;
  String _activity = 'raid';
  late DateTime _start;
  int _duration = 120;
  int? _max = 10;
  bool _weekly = false;
  Map<String, int> _roles = {...eventRolePresets['squad10']!};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      final e = editing.event;
      _title.text = e.title;
      _description.text = e.description;
      _guildId = e.guildId;
      _activity = eventActivities.contains(e.activity) ? e.activity : 'other';
      _start = e.startAt;
      _duration = e.durationMinutes;
      _max = e.maxParticipants;
      _roles = {...editing.roles};
      return;
    }
    // tomorrow at the next full hour, a sensible first guess
    final now = DateTime.now().add(const Duration(days: 1));
    _start = DateTime(now.year, now.month, now.day, now.hour + 1);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return;
    setState(() => _start = DateTime(day.year, day.month, day.day, _start.hour, _start.minute));
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _start.hour, minute: _start.minute),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (time == null || !mounted) return;
    setState(() => _start = DateTime(_start.year, _start.month, _start.day, time.hour, time.minute));
  }

  /// the account chosen, or the only one that may when there is just one
  String? _effectiveAccount(List<GuildAccount> all) {
    final guild = _guildId;
    if (guild == null) return null;
    final organizers = organizersFor(all, guild);
    if (_accountId != null && organizers.any((a) => a.accountId == _accountId)) return _accountId;
    return organizers.length == 1 ? organizers.first.accountId : null;
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final guild = _guildId;
    final title = _title.text.trim();
    final account = _effectiveAccount(ref.read(myGuildAccountsProvider).valueOrNull ?? const []);
    if (guild == null) {
      showToast(context, s.t('event_err_guild'));
      return;
    }
    if (title.isEmpty) {
      showToast(context, s.t('event_err_title'));
      return;
    }
    if (widget.editing == null && account == null) {
      showToast(context, s.t('event_err_account'));
      return;
    }
    setState(() => _busy = true);
    try {
      final description = _description.text.trim();
      final editing = widget.editing;
      if (editing != null) {
        await updateEvent(
          eventId: editing.event.id,
          version: editing.event.version,
          title: title,
          startAt: _start,
          durationMinutes: _duration,
          description: description,
          activity: _activity,
          maxParticipants: _max,
          roles: _roles,
        );
      } else if (_weekly) {
        await createWeeklyEvent(
          guildId: guild,
          accountId: account,
          title: title,
          firstStart: _start,
          durationMinutes: _duration,
          description: description,
          activity: _activity,
          maxParticipants: _max,
          roles: _roles,
        );
      } else {
        await createEvent(
          guildId: guild,
          accountId: account,
          title: title,
          startAt: _start,
          durationMinutes: _duration,
          description: description,
          activity: _activity,
          maxParticipants: _max,
          roles: _roles,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showToast(context, eventFailureText(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final editing = widget.editing;
    final creatable = ref.watch(creatableGuildsProvider).valueOrNull ?? const <MyGuild>[];
    // the creator may edit an event in a guild where they are no officer
    final guilds = editing == null
        ? creatable
        : [MyGuild(editing.event.guildId, editing.event.guildName, editing.event.guildTag, 'member')];
    // no guild is preselected: choosing it is part of creating the event
    final guildId = _guildId;
    final accounts = ref.watch(myGuildAccountsProvider);
    final organizers =
        guildId == null ? const <GuildAccount>[] : organizersFor(accounts.valueOrNull ?? const [], guildId);
    final accountId = _effectiveAccount(accounts.valueOrNull ?? const []);
    final durations = {30, 60, 90, 120, 180, 240, _duration}.toList()..sort();
    final sizes = <int?>{5, 10, 20, 50, _max}.whereType<int>().toList()..sort();
    final roleTotal = _roles.values.fold<int>(0, (a, b) => a + b);

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(editing == null ? s.t('event_create') : s.t('event_edit'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          label(s.t('event_guild')),
          DropdownButtonFormField<String>(
            initialValue: guildId,
            dropdownColor: AppColors.surface,
            decoration: fieldDecoration(''),
            hint: Text(s.t('event_guild_hint'), style: TextStyle(color: AppColors.muted)),
            items: [
              for (final g in guilds)
                DropdownMenuItem(value: g.id, child: Text(g.tag.isEmpty ? g.name : '${g.name} [${g.tag}]')),
            ],
            // another guild has other accounts to organize with
            onChanged: editing != null
                ? null
                : (v) => setState(() {
                      _guildId = v;
                      _accountId = null;
                    }),
          ),
          // which of the player's accounts creates it: roles are per account
          if (editing == null && guildId != null) ...[
            label(s.t('event_account')),
            if (organizers.isEmpty && accounts.hasValue)
              Text(s.t('event_account_none'), style: TextStyle(fontSize: 13, color: AppColors.muted))
            else
              DropdownButtonFormField<String>(
                // a new field for every guild, its start value is read once
                key: ValueKey('organizer-$guildId'),
                initialValue: accountId,
                dropdownColor: AppColors.surface,
                decoration: fieldDecoration(''),
                hint: Text(s.t('event_account_hint'), style: TextStyle(color: AppColors.muted)),
                items: [
                  for (final a in organizers)
                    DropdownMenuItem(
                        value: a.accountId, child: Text('${a.accountName} · ${rankLabel(s, a.role, a.gw2Rank)}')),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
          ],
          label(s.t('event_title')),
          TextField(controller: _title, maxLength: 80, decoration: fieldDecoration(s.t('event_title_hint'))),
          label(s.t('event_activity')),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in eventActivities)
                ChoiceChip(
                  avatar: Icon(activityIcon(a), size: 16),
                  label: Text(s.t('activity_$a')),
                  selected: _activity == a,
                  onSelected: (_) => setState(() => _activity = a),
                ),
            ],
          ),
          label(s.t('event_when')),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label:
                      Text('${s.t('wd_${_start.weekday}')} ${pad2(_start.day)}.${pad2(_start.month)}.${_start.year}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(_clock(_start)),
                ),
              ),
            ],
          ),
          if (editing == null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _weekly,
              onChanged: (v) => setState(() => _weekly = v),
              title: Text(s.t('event_repeat_weekly')),
              subtitle: Text(s.t('event_repeat_note'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
          label(s.t('event_duration')),
          Wrap(
            spacing: 6,
            children: [
              for (final m in durations)
                ChoiceChip(
                  label: Text(m < 60 ? '$m min' : '${m ~/ 60}${m % 60 == 0 ? '' : '.5'} h'),
                  selected: _duration == m,
                  onSelected: (_) => setState(() => _duration = m),
                ),
            ],
          ),
          label(s.t('event_size')),
          Wrap(
            spacing: 6,
            children: [
              for (final n in <int?>[...sizes, null])
                ChoiceChip(
                  label: Text(n == null ? s.t('event_size_open') : '$n'),
                  selected: _max == n,
                  onSelected: (_) => setState(() => _max = n),
                ),
            ],
          ),
          label(s.t('event_roles')),
          Wrap(
            spacing: 6,
            children: [
              ActionChip(
                label: Text(s.t('event_preset_squad10')),
                onPressed: () => setState(() {
                  _roles = {...eventRolePresets['squad10']!};
                  _max = 10;
                }),
              ),
              ActionChip(
                label: Text(s.t('event_preset_party5')),
                onPressed: () => setState(() {
                  _roles = {...eventRolePresets['party5']!};
                  _max = 5;
                }),
              ),
              ActionChip(label: Text(s.t('event_preset_none')), onPressed: () => setState(() => _roles = {})),
            ],
          ),
          const SizedBox(height: 6),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                for (final key in eventRoleKeys)
                  Row(
                    children: [
                      Expanded(child: Text(s.t('role_$key'))),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: (_roles[key] ?? 0) == 0
                            ? null
                            : () => setState(() {
                                  final n = (_roles[key] ?? 0) - 1;
                                  n == 0 ? _roles.remove(key) : _roles[key] = n;
                                }),
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                      ),
                      SizedBox(
                        width: 24,
                        child: Text('${_roles[key] ?? 0}',
                            textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _roles[key] = (_roles[key] ?? 0) + 1),
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (_max != null && roleTotal > _max!)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(s.t('event_roles_over', {'n': roleTotal, 'max': _max!}),
                  style: TextStyle(fontSize: 12, color: AppColors.gold)),
            ),
          label(s.t('event_description')),
          TextField(
            controller: _description,
            maxLength: 2000,
            minLines: 3,
            maxLines: 8,
            decoration: fieldDecoration(s.t('event_description_hint')),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy || guilds.isEmpty ? null : _save,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(editing == null ? s.t('event_create') : s.t('event_save')),
          ),
          if (editing?.event.seriesId != null) ...[
            const SizedBox(height: 8),
            Text(s.t('event_edit_one_week'),
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}
