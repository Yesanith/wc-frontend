part of '../settings_screen.dart';

/// the tyria companion account: separate from the gw2 api keys above, it
/// is what guild events, friends and the discord bot will hang on
class _CommunityPanel extends ConsumerStatefulWidget {
  const _CommunityPanel();

  @override
  ConsumerState<_CommunityPanel> createState() => _CommunityPanelState();
}

class _CommunityPanelState extends ConsumerState<_CommunityPanel> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) showToast(context, s.t('community_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final s = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(s.t('community_delete')),
        content: Text(s.t('community_delete_body')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.t('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.t('community_delete_confirm')),
          ),
        ],
      ),
    );
    if (ok == true) await _run(deleteAccount);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final session = ref.watch(sessionProvider).valueOrNull;
    final profile = session == null ? null : ref.watch(myProfileProvider).valueOrNull;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(s.t('community_account').toUpperCase()),
          const SizedBox(height: 10),
          if (session == null) ...[
            Text(s.t('community_intro'), style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted)),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5865F2), foregroundColor: Colors.white),
              onPressed: _busy ? null : () => _run(signInWithDiscord),
              icon: const Icon(Icons.login),
              label: Text(s.t('community_sign_in_discord')),
            ),
          ] else ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.surface2,
                  foregroundImage: profile?.avatarUrl == null ? null : NetworkImage(profile!.avatarUrl!),
                  child: const Icon(Icons.person_outline, color: AppColors.muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile?.displayName ?? '…', style: display(17)),
                      Text(s.t('community_signed_in'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _Gw2LinkSection(),
            if (pushReady) const _PushSwitch(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _run(signOut),
                    child: Text(s.t('community_sign_out')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: AppColors.red),
                    onPressed: _busy ? null : _confirmDelete,
                    child: Text(s.t('community_delete')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// the gw2 accounts linked to the community account and the guilds they are
/// in. linking uses a short lived subtoken, the api key stays on the device
class _Gw2LinkSection extends ConsumerStatefulWidget {
  const _Gw2LinkSection();

  @override
  ConsumerState<_Gw2LinkSection> createState() => _Gw2LinkSectionState();
}

class _Gw2LinkSectionState extends ConsumerState<_Gw2LinkSection> {
  bool _busy = false;

  /// the refresh button is the one running, not the link button
  bool _refreshing = false;

  Future<void> _link({bool quiet = false}) async {
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    try {
      final permissions = [
        for (final p in ((await ref.read(tokenInfoProvider.future))['permissions'] as List?) ?? const []) '$p',
      ];
      final name = await linkGw2Account(ref.read(gw2ApiProvider), permissions);
      ref.invalidate(linkedAccountsProvider);
      ref.invalidate(myGuildsProvider);
      if (!quiet && mounted) showToast(context, s.t('gw2_linked', {'name': name}));
    } on LinkFailure catch (e) {
      // the code travels with the message so a report tells which step failed
      if (!quiet && mounted) {
        showToast(context, '${s.t(_failureKey(e.code))} (${e.code})', duration: const Duration(seconds: 6));
      }
    } catch (e) {
      if (!quiet && mounted) {
        showToast(context, '${s.t('community_failed')} ($e)', duration: const Duration(seconds: 6));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// refreshes the guilds of the account that is linked already: its
  /// membership, and for a guild's leader what the game tells only the leader.
  /// this is not linking, another account is linked with the other button
  Future<void> _refresh() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _refreshing = true;
    });
    try {
      final leads = (ref.read(myGuildsProvider).valueOrNull ?? const <MyGuild>[]).any((g) => g.role == 'leader');
      final outcome = await refreshLink(ref, force: true);
      if (!mounted) return;
      // a leader is told how the guild's sync went, anybody else that it is done
      showToast(
        context,
        outcome == null || leads ? guildSyncMessage(s, outcome) : s.t('gw2_refreshed'),
        duration: const Duration(seconds: 6),
      );
    } on LinkFailure catch (e) {
      if (mounted) {
        showToast(context, '${s.t(_failureKey(e.code))} (${e.code})', duration: const Duration(seconds: 6));
      }
    } catch (e) {
      if (mounted) showToast(context, '${s.t('community_failed')} ($e)', duration: const Duration(seconds: 6));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _refreshing = false;
        });
      }
    }
  }

  String _failureKey(String code) => switch (code) {
        'account_taken' => 'gw2_link_taken',
        'invalid_token' || 'missing_permission' => 'gw2_link_key',
        'gw2_unavailable' => 'gw2_link_down',
        'subtoken_failed' => 'gw2_link_key',
        _ => 'community_failed',
      };

  Future<void> _unlink(LinkedAccount account) async {
    final s = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(s.t('gw2_unlink')),
        content: Text(s.t('gw2_unlink_body', {'name': account.name})),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.t('gw2_unlink'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await unlinkGw2Account(account.id);
      ref.invalidate(linkedAccountsProvider);
      ref.invalidate(myGuildsProvider);
    } catch (_) {
      if (mounted) showToast(context, s.t('community_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final accounts = ref.watch(linkedAccountsProvider).valueOrNull;
    final guilds = ref.watch(myGuildsProvider).valueOrNull ?? const <MyGuild>[];

    // the account of the active API key, and whether it is one of the linked ones
    final activeName = '${ref.watch(accountProvider).valueOrNull?['name'] ?? ''}';
    final hasAccounts = accounts != null && accounts.isNotEmpty;
    final activeLinked = accounts != null &&
        activeName.isNotEmpty &&
        accounts.any((a) => a.name.toLowerCase() == activeName.toLowerCase());
    const spinner = SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.t('gw2_accounts_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (accounts == null)
          const LinearProgressIndicator(minHeight: 2, color: AppColors.gold)
        else if (accounts.isEmpty)
          Text(s.t('gw2_link_intro'), style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted))
        else
          for (final a in accounts)
            Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(child: Text(a.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                IconButton(
                  tooltip: s.t('gw2_unlink'),
                  visualDensity: VisualDensity.compact,
                  onPressed: _busy ? null : () => _unlink(a),
                  icon: const Icon(Icons.link_off, size: 18, color: AppColors.muted),
                ),
              ],
            ),
        if (guilds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in guilds)
                // tapping a guild shows its members, where leaders appoint officers
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => GuildRosterScreen(guild: g)),
                  ),
                  child: Pill(
                    g.tag.isEmpty
                        ? '${g.name} · ${rankLabel(s, g.role, g.gw2Rank)} ›'
                        : '${g.name} [${g.tag}] · ${rankLabel(s, g.role, g.gw2Rank)} ›',
                    color: g.role == 'leader' ? AppColors.gold : AppColors.textSoft,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        // linking is one thing, for the account of the active API key when it is not
        // linked yet. refreshing the guilds of a linked account is another
        if (!activeLinked)
          OutlinedButton.icon(
            onPressed: _busy ? null : _link,
            icon: _busy && !_refreshing ? spinner : const Icon(Icons.link, size: 18),
            label: Text(activeName.isEmpty ? s.t('gw2_link') : s.t('gw2_link_name', {'name': activeName})),
          ),
        if (hasAccounts) ...[
          if (!activeLinked) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy || !activeLinked ? null : _refresh,
            icon: _refreshing ? spinner : const Icon(Icons.refresh, size: 18),
            label: Text(s.t('gw2_refresh')),
          ),
          if (!activeLinked)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(s.t('gw2_refresh_other'),
                  style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.hint)),
            ),
        ],
        const SizedBox(height: 4),
        Text(s.t('gw2_link_note'), style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.hint)),
      ],
    );
  }
}

/// event reminders and waitlist news on this device
class _PushSwitch extends ConsumerStatefulWidget {
  const _PushSwitch();

  @override
  ConsumerState<_PushSwitch> createState() => _PushSwitchState();
}

class _PushSwitchState extends ConsumerState<_PushSwitch> {
  bool _busy = false;

  Future<void> _set(bool on) async {
    final s = ref.read(stringsProvider);
    final prefs = ref.read(prefsProvider);
    setState(() => _busy = true);
    try {
      if (on) {
        final allowed = await enablePush(ref.read(langProvider).code);
        await prefs.setBool(pushPref, allowed);
        if (!allowed && mounted) showToast(context, s.t('push_denied'));
      } else {
        await disablePush();
        await prefs.setBool(pushPref, false);
      }
    } catch (_) {
      if (mounted) showToast(context, s.t('community_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final on = ref.watch(prefsProvider).getBool(pushPref) != false;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: on,
      onChanged: _busy ? null : _set,
      title: Text(s.t('push_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      subtitle: Text(s.t('push_note'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    );
  }
}
