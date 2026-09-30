import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../services/backup.dart';
import '../services/icon_cache.dart';
import '../services/sync.dart';
import '../services/update_check.dart';
import '../state/account.dart';
import '../state/api.dart';
import '../services/boss_alerts.dart';
import '../services/push.dart';
import '../state/boss_alerts.dart';
import '../state/community.dart';
import '../state/link_refresh.dart';
import 'guild_roster_screen.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    // the dialog owns its text field's controller: disposing it here, as soon
    // as the dialog returned, broke the field while the dialog animated out
    final text = await showDialog<String>(context: context, builder: (_) => _ImportDialog(s: s));
    if (text == null || text.trim().isEmpty) return;
    var message = s.t('imported');
    try {
      await restoreBackup(ref, text);
    } catch (_) {
      message = s.t('import_failed');
    }
    if (context.mounted) {
      showToast(context, message);
    }
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    await clearCache(ref.read(diskCacheProvider));
    // the copy in memory too, otherwise the next save writes it straight back
    ref.read(gw2ApiProvider).clearStaticCaches();
    await ref.read(iconCacheProvider)?.clear();
    if (context.mounted) {
      showToast(context, s.t('cache_cleared'));
    }
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final current = ref.watch(langProvider);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final l in AppLang.values)
                    ListTile(
                      onTap: () {
                        ref.read(langProvider.notifier).set(l);
                        Navigator.of(ctx).pop();
                      },
                      leading: Icon(
                        l == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: l == current ? AppColors.gold : AppColors.muted,
                      ),
                      title: Text(l.nativeName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: Text(l.code.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(langProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker(s.t('language').toUpperCase()),
              const SizedBox(height: 4),
              // one line instead of nine, the list opens from the bottom
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => _pickLanguage(context, ref),
                leading: const Icon(Icons.translate, color: AppColors.gold),
                title: Text(lang.nativeName, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(lang.code.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more, color: AppColors.muted),
                  ],
                ),
              ),
              const Divider(color: AppColors.track),
              const SizedBox(height: 4),
              _InfoRow(
                s.t('data_language'),
                lang.apiLang == lang.code ? lang.nativeName : s.t('data_lang_fallback'),
              ),
              const SizedBox(height: 6),
              _InfoRow(s.t('wiki_source'), Uri.parse(lang.wikiBase).host),
            ],
          ),
        ),
        // shown only in builds that know the community backend
        if (communityReady) ...[
          const SizedBox(height: 16),
          const _CommunityPanel(),
        ],
        const SizedBox(height: 16),
        const _AccountsPanel(),
        const SizedBox(height: 16),
        const _SyncPanel(),
        if (bossAlertsReady) ...[
          const SizedBox(height: 16),
          const _BossAlertsPanel(),
        ],
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker(s.t('backup').toUpperCase()),
              const SizedBox(height: 8),
              Text(s.t('backup_note'), style: const TextStyle(fontSize: 13, color: AppColors.textSoft, height: 1.4)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => shareBackup(ref),
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: Text(s.t('export_backup')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _import(context, ref),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(s.t('import_backup')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _clearCache(context, ref),
                icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                label: Text(s.t('clear_cache')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _UpdatePanel(),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// launch sync status, with a way to pull the account down again
class _SyncPanel extends ConsumerWidget {
  const _SyncPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final sync = ref.watch(syncProvider);
    final at = sync.finishedAt;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(s.t('sync_now').toUpperCase()),
          const SizedBox(height: 8),
          Text(s.t('sync_note'), style: const TextStyle(fontSize: 13, color: AppColors.textSoft, height: 1.4)),
          if (sync.running) ...[
            const SizedBox(height: 12),
            Bar(value: sync.ratio),
            const SizedBox(height: 6),
            Text('${s.t('syncing')} ${sync.done}/${sync.total}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ] else if (at != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${_two(at.hour)}:${_two(at.minute)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                if (sync.failed > 0) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.error_outline, size: 14, color: AppColors.red),
                  const SizedBox(width: 4),
                  Text('${sync.failed}', style: const TextStyle(fontSize: 12, color: AppColors.red)),
                ],
              ],
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: sync.running ? null : () => ref.read(syncProvider.notifier).run(),
            icon: const Icon(Icons.sync, size: 18),
            label: Text(s.t('sync_now')),
          ),
        ],
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// shows the installed version and offers the apk of a newer release
class _UpdatePanel extends ConsumerWidget {
  const _UpdatePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final update = ref.watch(updateProvider);
    final latest = update.valueOrNull;
    final hasUpdate = latest != null && latest.isNewerThan;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.t('version'), style: const TextStyle(fontSize: 14, color: AppColors.textSoft)),
              ),
              const Text(appVersion,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.gold)),
              IconButton(
                tooltip: s.t('check_updates'),
                onPressed: () => ref.invalidate(updateProvider),
                icon: const Icon(Icons.refresh, size: 20, color: AppColors.muted),
              ),
            ],
          ),
          if (update.isLoading)
            Text(s.t('checking'), style: const TextStyle(fontSize: 12, color: AppColors.muted))
          else if (update.hasError)
            Text(s.t('check_failed'), style: const TextStyle(fontSize: 12, color: AppColors.muted))
          else if (hasUpdate) ...[
            Text(s.t('update_available', {'v': latest.version}),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => openUrl(
                      context,
                      latest.apkUrl ?? latest.pageUrl,
                      failMessage: s.t('open_failed'),
                    ),
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(s.t('download_update')),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => openUrl(context, latest.pageUrl, failMessage: s.t('open_failed')),
                  child: Text(s.t('release_notes')),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(s.t('install_note'), style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.hint)),
          ] else
            Text(s.t('up_to_date'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// switch between saved api keys, add or remove them
class _AccountsPanel extends ConsumerWidget {
  const _AccountsPanel();

  String _mask(String key) =>
      key.length <= 12 ? '********' : '${key.substring(0, 8)}...${key.substring(key.length - 4)}';

  Future<void> _remove(BuildContext context, WidgetRef ref, int index, String label) async {
    final s = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(s.t('remove_key')),
        content: Text(s.t('remove_key_body')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.t('remove'))),
        ],
      ),
    );
    if (ok == true) await ref.read(keysProvider.notifier).removeAt(index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final keys = ref.watch(keysProvider).valueOrNull ?? const <StoredKey>[];
    final active = ref.watch(activeKeyProvider);
    final info = ref.watch(tokenInfoProvider);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(s.t('accounts').toUpperCase()),
          const SizedBox(height: 4),
          for (var i = 0; i < keys.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => ref.read(activeKeyProvider.notifier).set(i),
              leading: Icon(
                i == active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: i == active ? AppColors.gold : AppColors.muted,
              ),
              title: Text(keys[i].name.isEmpty ? s.t('unnamed_account') : keys[i].name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_mask(keys[i].key),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.muted)),
              trailing: IconButton(
                tooltip: s.t('remove_key'),
                onPressed: () => _remove(context, ref, i, keys[i].name),
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.muted),
              ),
            ),
          const SizedBox(height: 4),
          if (keys.isEmpty)
            Text(s.t('guest_note'), style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted))
          else
            AsyncView<Json>(
              value: info,
              onRetry: () => ref.invalidate(tokenInfoProvider),
              builder: (i) {
                final perms = ((i['permissions'] as List?) ?? const []).map((e) => '$e').toList();
                return Wrap(spacing: 6, runSpacing: 6, children: [for (final p in perms) Pill(p)]);
              },
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(keys.isEmpty ? s.t('add_api_key') : s.t('add_account')),
          ),
        ],
      ),
    );
  }
}

/// the paste field for a backup, which disposes its own controller once the
/// dialog is gone
class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.s});

  final S s;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(s.t('import_backup')),
      content: TextField(
        controller: _ctrl,
        maxLines: 6,
        decoration: fieldDecoration(s.t('import_hint')),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.t('cancel'))),
        FilledButton(onPressed: () => Navigator.of(context).pop(_ctrl.text), child: Text(s.t('import_backup'))),
      ],
    );
  }
}

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

    String role(String r) => s.t('guild_role_$r');

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
                    g.tag.isEmpty ? '${g.name} · ${role(g.role)} ›' : '${g.name} [${g.tag}] · ${role(g.role)} ›',
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
      activeThumbColor: AppColors.gold,
      onChanged: _busy ? null : _set,
      title: Text(s.t('push_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      subtitle: Text(s.t('push_note'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    );
  }
}

/// alerts before the world events the player pinned. they come from the
/// phone's own alarms, so they need no account and no server
class _BossAlertsPanel extends ConsumerStatefulWidget {
  const _BossAlertsPanel();

  @override
  ConsumerState<_BossAlertsPanel> createState() => _BossAlertsPanelState();
}

class _BossAlertsPanelState extends ConsumerState<_BossAlertsPanel> {
  bool _busy = false;

  Future<void> _turnOn(bool on) async {
    final s = ref.read(stringsProvider);
    await ref.read(bossAlertSettingsProvider.notifier).setEnabled(on);
    if (!on) return;
    setState(() => _busy = true);
    final allowed = await requestBossAlertPermission();
    ref.read(bossAlertsRecheckProvider.notifier).bump();
    if (mounted) {
      setState(() => _busy = false);
      if (!allowed) showToast(context, s.t('push_denied'));
    }
  }

  Future<void> _test() async {
    final s = ref.read(stringsProvider);
    if (!await requestBossAlertPermission()) {
      if (mounted) showToast(context, s.t('push_denied'));
      return;
    }
    await showBossAlertTest(
      title: 'Tyria Codex',
      body: s.t('boss_alert_test_body'),
      channelName: s.t('boss_alerts_title'),
      channelDescription: s.t('boss_alerts_note'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(bossAlertSettingsProvider);
    final pins = ref.watch(pinnedEventsProvider);
    final status = ref.watch(bossAlertStatusProvider).valueOrNull;
    final plan = settings.enabled ? alertsFor(pins, settings.lead, s) : const BossAlertPlan([], []);
    final count = plan.alerts.length;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.enabled,
            activeThumbColor: AppColors.gold,
            onChanged: _busy ? null : _turnOn,
            title: Text(s.t('boss_alerts_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            subtitle: Text(s.t('boss_alerts_note'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
          if (settings.enabled) ...[
            const SizedBox(height: 8),
            Text(s.t('boss_alerts_lead'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final m in bossAlertLeads)
                  ChoiceChip(
                    label: Text(s.t('minutes_short', {'n': m})),
                    selected: settings.lead == m,
                    onSelected: (_) => ref.read(bossAlertSettingsProvider.notifier).setLead(m),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              pins.isEmpty ? s.t('boss_alert_none') : s.t('boss_alert_scheduled', {'pins': pins.length, 'n': count}),
              style: const TextStyle(fontSize: 12, color: AppColors.textSoft),
            ),
            if (plan.skipped.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                s.t('boss_alert_limit', {'n': plan.skipped.length, 'max': maxBossAlerts}),
                style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.gold),
              ),
            ],
            if (status != null && !status.notifications) ...[
              const SizedBox(height: 10),
              FilledButton(onPressed: _busy ? null : () => _turnOn(true), child: Text(s.t('boss_alert_allow'))),
            ],
            if (status != null && status.notifications && !status.exact) ...[
              const SizedBox(height: 10),
              Text(s.t('boss_alert_exact_note'),
                  style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
              const SizedBox(height: 6),
              OutlinedButton(
                onPressed: () async {
                  await openExactAlarmSettings();
                  ref.read(bossAlertsRecheckProvider.notifier).bump();
                },
                child: Text(s.t('boss_alert_exact_button')),
              ),
            ],
            const SizedBox(height: 6),
            TextButton(onPressed: _test, child: Text(s.t('boss_alert_test'))),
          ],
        ],
      ),
    );
  }
}
