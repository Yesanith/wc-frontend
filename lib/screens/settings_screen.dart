import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../services/backup.dart';
import '../services/update_check.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _mask(String key) {
    if (key.length <= 12) return '********';
    return '${key.substring(0, 8)}...${key.substring(key.length - 4)}';
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(s.t('import_backup')),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: fieldDecoration(s.t('import_hint')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: Text(s.t('import_backup'))),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    var message = s.t('imported');
    try {
      await restoreBackup(ref, text);
    } catch (_) {
      message = s.t('import_failed');
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    await clearCache(ref.read(diskCacheProvider));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('cache_cleared'))));
    }
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
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
    if (ok == true) {
      await ref.read(apiKeyProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(langProvider);
    final info = ref.watch(tokenInfoProvider);
    final key = ref.watch(apiKeyProvider).valueOrNull ?? '';

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
              for (final l in AppLang.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => ref.read(langProvider.notifier).set(l),
                  leading: Icon(
                    l == lang ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: l == lang ? AppColors.gold : AppColors.muted,
                  ),
                  title: Text(l.nativeName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: Text(l.code.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
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
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker(s.t('api_key').toUpperCase()),
              const SizedBox(height: 8),
              Text(_mask(key), style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
              const SizedBox(height: 14),
              AsyncView<Json>(
                value: info,
                onRetry: () => ref.invalidate(tokenInfoProvider),
                builder: (i) {
                  final perms = ((i['permissions'] as List?) ?? const []).map((e) => '$e').toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('key_name', {'n': i['name'] ?? '-'}),
                          style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [for (final p in perms) Pill(p)],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
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
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _confirmRemove(context, ref),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.red,
            side: const BorderSide(color: AppColors.red),
            minimumSize: const Size.fromHeight(50),
          ),
          icon: const Icon(Icons.logout),
          label: Text(s.t('remove_key')),
        ),
        const SizedBox(height: 22),
        const _UpdatePanel(),
        const SizedBox(height: 22),
        Text(s.t('disclaimer'), style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.hint)),
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
