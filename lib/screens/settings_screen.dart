import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
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
import '../state/module_link.dart';
import 'guild_roster_screen.dart';
import '../state/settings.dart';
import '../state/trade_notify.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/site_header.dart' show sitePageUrl;
import '../widgets/ui_zoom.dart';
import 'onboarding_screen.dart';

part 'settings/sync.dart';
part 'settings/accounts.dart';
part 'settings/community.dart';
part 'settings/module.dart';
part 'settings/alerts.dart';

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
                          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
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
    final signedIn = communityReady && ref.watch(sessionProvider).valueOrNull != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // who the player is: the community account (shown only in builds that know the backend), the keys of the game,
        // and the addons of the game that link to the account
        if (communityReady)
          _Section(
            title: s.t('settings_account'),
            note: s.t('settings_account_note'),
            children: const [_CommunityPanel()],
          ),
        _Section(
          title: s.t('settings_keys'),
          note: s.t('settings_keys_note'),
          children: const [_AccountsPanel()],
        ),
        if (signedIn)
          _Section(
            title: s.t('settings_modules'),
            note: s.t('settings_modules_note'),
            children: const [_ModuleLinkPanel()],
          ),
        // how the app looks, in one card
        _Section(
          title: s.t('settings_appearance'),
          note: s.t('settings_appearance_note'),
          children: [
            Panel(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(s.t('look').toUpperCase()),
                  const SizedBox(height: 10),
                  const _LookChoice(),
                  Divider(height: 28, color: AppColors.track),
                  Kicker(s.t('language').toUpperCase()),
                  const SizedBox(height: 4),
                  // one line instead of nine, the list opens from the bottom
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _pickLanguage(context, ref),
                    leading: Icon(Icons.translate, color: AppColors.gold),
                    title: Text(lang.nativeName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(lang.code.toUpperCase(),
                            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
                        const SizedBox(width: 4),
                        Icon(Icons.expand_more, color: AppColors.muted),
                      ],
                    ),
                  ),
                  _InfoRow(
                    s.t('data_language'),
                    lang.apiLang == lang.code ? lang.nativeName : s.t('data_lang_fallback'),
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(s.t('wiki_source'), Uri.parse(lang.wikiBase).host),
                  if (kIsWeb) ...[
                    Divider(height: 28, color: AppColors.track),
                    const _UiSizeChoice(),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (bossAlertsReady)
          _Section(
            title: s.t('settings_notifications'),
            note: s.t('settings_notifications_note'),
            children: [
              const _BossAlertsPanel(),
              const _ResetAlertsPanel(),
              // what the trading post did for the player, from the phone: the api key stays on it
              if (!kIsWeb) const _TradeNotifyPanel(),
            ],
          ),
        _Section(
          title: s.t('settings_data'),
          note: s.t('settings_data_note'),
          children: [
            const _SyncPanel(),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(s.t('backup').toUpperCase()),
                  const SizedBox(height: 8),
                  Text(s.t('backup_note'), style: TextStyle(fontSize: 13, color: AppColors.textSoft, height: 1.4)),
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
          ],
        ),
        // an apk cannot be installed from a browser
        if (!kIsWeb) _Section(title: s.t('settings_app'), children: const [_UpdatePanel()]),
      ],
    );
  }
}

/// a group of the settings: a title, a line on what it is for, and its cards one under the other
class _Section extends StatelessWidget {
  const _Section({required this.title, this.note, required this.children});

  final String title;
  final String? note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final n = note;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: display(18)),
                if (n != null) ...[
                  const SizedBox(height: 3),
                  Text(n, style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
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
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.muted))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// how large the interface is in the browser: automatic, which grows with a wide screen, or one of the sizes
class _UiSizeChoice extends ConsumerWidget {
  const _UiSizeChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final chosen = ref.watch(uiScaleProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(s.t('ui_scale').toUpperCase()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final size in uiScaleChoices)
              ChoiceChip(
                label: Text(size == null ? s.t('ui_scale_auto') : '${(size * 100).round()}%'),
                selected: chosen == size,
                onSelected: (_) => ref.read(uiScaleProvider.notifier).set(size),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(s.t('ui_scale_hint'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}

/// light, dark or whichever the phone is set to
class _LookChoice extends ConsumerWidget {
  const _LookChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final mode = ref.watch(lookProvider);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<LookMode>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: LookMode.system,
            icon: const Icon(Icons.brightness_auto_outlined, size: 18),
            label: Text(s.t('look_system')),
          ),
          ButtonSegment(
            value: LookMode.light,
            icon: const Icon(Icons.light_mode_outlined, size: 18),
            label: Text(s.t('look_light')),
          ),
          ButtonSegment(
            value: LookMode.dark,
            icon: const Icon(Icons.dark_mode_outlined, size: 18),
            label: Text(s.t('look_dark')),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (picked) => ref.read(lookProvider.notifier).set(picked.first),
      ),
    );
  }
}
